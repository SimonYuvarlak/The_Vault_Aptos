module vault::vault {
    use std::signer;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};

    /// Error Codes
    const E_NOT_ADMIN: u64 = 1;
    const E_PERMISSION_DENIED: u64 = 2;
    const E_INSUFFICIENT_BALANCE: u64 = 3;
    const E_NO_ALLOCATION: u64 = 4;
    const E_ADDRESS_NOT_FOUND: u64 = 5;

    /// Events
    struct PermissionGrantedEvent has drop, store { address: address }
    struct PermissionRevokedEvent has drop, store { address: address }
    struct AllocationMadeEvent has drop, store { address: address, amount: u64 }
    struct AllocationClaimedEvent has drop, store { address: address, amount: u64 }
    struct AllocationCanceledEvent has drop, store { address: address, amount: u64 }
    struct AdminChangedEvent has drop, store { old_admin: address, new_admin: address }
    struct TokensDepositedEvent has drop, store { depositor: address, amount: u64 }
    struct TokensWithdrawnEvent has drop, store { amount: u64 }

    /// The Vault struct
    struct Vault has key {
        admin: address,
        vault_address: address,
        permissions: vector<address>,
        allocations: Table<address, u64>,
        total_allocated: u64,
        total_balance: u64,
        permission_granted_events: EventHandle<PermissionGrantedEvent>,
        permission_revoked_events: EventHandle<PermissionRevokedEvent>,
        allocation_made_events: EventHandle<AllocationMadeEvent>,
        allocation_claimed_events: EventHandle<AllocationClaimedEvent>,
        allocation_canceled_events: EventHandle<AllocationCanceledEvent>,
        admin_changed_events: EventHandle<AdminChangedEvent>,
        tokens_deposited_events: EventHandle<TokensDepositedEvent>,
        tokens_withdrawn_events: EventHandle<TokensWithdrawnEvent>,
    }

    struct VaultSignerCapability has key, store {
        cap: account::SignerCapability
    }

    /// Initialize the module
    fun init_module(resource_account: &signer) {
        let resource_account_address = signer::address_of(resource_account);
        
        let (vault_signer, vault_signer_cap) = account::create_resource_account(resource_account, b"VAULT");
        let vault_address = signer::address_of(&vault_signer);
        
        move_to(&vault_signer, Vault {
            admin: resource_account_address,
            vault_address,
            permissions: vector::empty(),
            allocations: table::new(),
            total_allocated: 0,
            total_balance: 0,
            permission_granted_events: account::new_event_handle<PermissionGrantedEvent>(&vault_signer),
            permission_revoked_events: account::new_event_handle<PermissionRevokedEvent>(&vault_signer),
            allocation_made_events: account::new_event_handle<AllocationMadeEvent>(&vault_signer),
            allocation_claimed_events: account::new_event_handle<AllocationClaimedEvent>(&vault_signer),
            allocation_canceled_events: account::new_event_handle<AllocationCanceledEvent>(&vault_signer),
            admin_changed_events: account::new_event_handle<AdminChangedEvent>(&vault_signer),
            tokens_deposited_events: account::new_event_handle<TokensDepositedEvent>(&vault_signer),
            tokens_withdrawn_events: account::new_event_handle<TokensWithdrawnEvent>(&vault_signer),
        });

        move_to(resource_account, VaultSignerCapability { cap: vault_signer_cap });
    }

    /// Get the vault's address from the admin's address
    #[view]
    public fun get_vault_address(admin_address: address): address acquires VaultSignerCapability {
        let vault_signer_cap = &borrow_global<VaultSignerCapability>(admin_address).cap;
        account::get_signer_capability_address(vault_signer_cap)
    }

    /// Deposit tokens into the Vault
    public entry fun deposit_tokens(account: &signer, vault_address: address, amount: u64) acquires Vault {
        let account_address = signer::address_of(account);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == account_address || vector::contains(&vault.permissions, &account_address), E_PERMISSION_DENIED);
        
        coin::transfer<AptosCoin>(account, vault.vault_address, amount);
        vault.total_balance = vault.total_balance + amount;

        event::emit_event(&mut vault.tokens_deposited_events, TokensDepositedEvent { depositor: account_address, amount });
    }

    /// Grant permission to deposit tokens
    public entry fun grant_permission(admin: &signer, vault_address: address, address: address) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        if (!vector::contains(&vault.permissions, &address)) {
            vector::push_back(&mut vault.permissions, address);
            event::emit_event(&mut vault.permission_granted_events, PermissionGrantedEvent { address });
        };
    }

    /// Revoke permission to deposit tokens
    public entry fun revoke_permission(admin: &signer, vault_address: address, address: address) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        let (found, index) = vector::index_of(&vault.permissions, &address);
        if (found) {
            vector::remove(&mut vault.permissions, index);
            event::emit_event(&mut vault.permission_revoked_events, PermissionRevokedEvent { address });
        };
    }

    /// Allocate tokens to a permissioned address
    public entry fun allocate_tokens(admin: &signer, vault_address: address, address: address, amount: u64) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        assert!(vault.total_balance >= vault.total_allocated + amount, E_INSUFFICIENT_BALANCE);

        let current_allocation = if (table::contains(&vault.allocations, address)) {
            *table::borrow(&vault.allocations, address)
        } else {
            0
        };
        table::upsert(&mut vault.allocations, address, current_allocation + amount);
        vault.total_allocated = vault.total_allocated + amount;
        event::emit_event(&mut vault.allocation_made_events, AllocationMadeEvent { address, amount });
    }

    /// Cancel allocation for an address
    public entry fun cancel_allocation(admin: &signer, vault_address: address, address: address) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        if (table::contains(&vault.allocations, address)) {
            let amount = table::remove(&mut vault.allocations, address);
            vault.total_allocated = vault.total_allocated - amount;
            event::emit_event(&mut vault.allocation_canceled_events, AllocationCanceledEvent { address, amount });
        };
    }

    /// Claim allocated tokens
    public entry fun claim_tokens(account: &signer, vault_address: address) acquires Vault, VaultSignerCapability {
        let account_address = signer::address_of(account);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(table::contains(&vault.allocations, account_address), E_NO_ALLOCATION);
        let amount = table::remove(&mut vault.allocations, account_address);
        vault.total_allocated = vault.total_allocated - amount;
        vault.total_balance = vault.total_balance - amount;

        let vault_signer_cap = &borrow_global<VaultSignerCapability>(vault.admin).cap;
        let vault_signer = account::create_signer_with_capability(vault_signer_cap);
        
        coin::transfer<AptosCoin>(&vault_signer, account_address, amount);
        event::emit_event(&mut vault.allocation_claimed_events, AllocationClaimedEvent { address: account_address, amount });
    }

    /// Withdraw unallocated tokens from the Vault
    public entry fun withdraw_tokens(admin: &signer, vault_address: address, amount: u64) acquires Vault, VaultSignerCapability {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        let available_balance = vault.total_balance - vault.total_allocated;
        assert!(available_balance >= amount, E_INSUFFICIENT_BALANCE);

        vault.total_balance = vault.total_balance - amount;

        let vault_signer_cap = &borrow_global<VaultSignerCapability>(vault.admin).cap;
        let vault_signer = account::create_signer_with_capability(vault_signer_cap);
        
        coin::transfer<AptosCoin>(&vault_signer, signer::address_of(admin), amount);
        event::emit_event(&mut vault.tokens_withdrawn_events, TokensWithdrawnEvent { amount });
    }

    /// Change the admin of the vault
    public entry fun change_admin(current_admin: &signer, vault_address: address, new_admin: address) acquires Vault, VaultSignerCapability {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(current_admin), E_NOT_ADMIN);
        
        let old_admin = vault.admin;
        vault.admin = new_admin;

        // Move the VaultSignerCapability to the new admin
        let VaultSignerCapability { cap } = move_from<VaultSignerCapability>(old_admin);
        move_to(&account::create_signer_with_capability(&cap), VaultSignerCapability { cap });

        event::emit_event(&mut vault.admin_changed_events, AdminChangedEvent { old_admin, new_admin });
    }

    /// Get the vault's balance
    #[view]
    public fun get_balance(vault_address: address): u64 acquires Vault {
        let vault = borrow_global<Vault>(vault_address);
        vault.total_balance
    }

    /// Get the total allocated amount
    #[view]
    public fun get_total_allocated(vault_address: address): u64 acquires Vault {
        let vault = borrow_global<Vault>(vault_address);
        vault.total_allocated
    }

    /// Check if an address has deposit permission
    #[view]
    public fun has_permission(vault_address: address, address: address): bool acquires Vault {
        let vault = borrow_global<Vault>(vault_address);
        vector::contains(&vault.permissions, &address)
    }

    /// Get the allocation for a specific address
    #[view]
    public fun get_allocation(vault_address: address, address: address): u64 acquires Vault {
        let vault = borrow_global<Vault>(vault_address);
        if (table::contains(&vault.allocations, address)) {
            *table::borrow(&vault.allocations, address)
        } else {
            0
        }
    }
}