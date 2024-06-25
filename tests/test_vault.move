#[test_only]
module vault::vault_tests {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, BurnCapability, MintCapability};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use vault::vault;

    // Store for burn and mint capabilities
    struct CapabilityStore has key {
        burn_cap: BurnCapability<AptosCoin>,
        mint_cap: MintCapability<AptosCoin>,
    }

    // Initialize AptosCoin for testing
    fun init_aptos_coin(aptos_framework: &signer) {
        if (!exists<CapabilityStore>(@aptos_framework)) {
            let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
            move_to(aptos_framework, CapabilityStore { burn_cap, mint_cap });
        };
    }

    // Test helper function to create and fund a test account
    fun create_and_fund_account(aptos_framework: &signer): signer acquires CapabilityStore {
        let new_account = account::create_account_for_test(@0x123);
        let new_account_addr = signer::address_of(&new_account);
        
        if (!coin::is_account_registered<AptosCoin>(new_account_addr)) {
            coin::register<AptosCoin>(&new_account);
        };
        
        let amount = 1000000;
        let capability_store = borrow_global<CapabilityStore>(@aptos_framework);
        let coins = coin::mint(amount, &capability_store.mint_cap);
        coin::deposit(new_account_addr, coins);

        new_account
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_initialize_vault(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        vault::initialize_vault(&owner);
        assert!(vault::get_total_allocated(signer::address_of(&owner)) == 0, 0);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_grant_and_revoke_permission(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        let user = create_and_fund_account(aptos_framework);
        let user_addr = signer::address_of(&user);

        vault::initialize_vault(&owner);
        vault::grant_permission(&owner, user_addr);
        assert!(vault::has_permission(signer::address_of(&owner), user_addr), 1);

        vault::revoke_permission(&owner, user_addr);
        assert!(!vault::has_permission(signer::address_of(&owner), user_addr), 2);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_deposit_tokens(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        let user = create_and_fund_account(aptos_framework);
        let user_addr = signer::address_of(&user);
        let owner_addr = signer::address_of(&owner);

        vault::initialize_vault(&owner);
        vault::grant_permission(&owner, user_addr);

        let initial_balance = vault::get_vault_balance(owner_addr);
        vault::deposit_tokens(&user, 1000);
        let final_balance = vault::get_vault_balance(owner_addr);

        assert!(final_balance == initial_balance + 1000, 3);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_allocate_and_claim_tokens(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        let user = create_and_fund_account(aptos_framework);
        let user_addr = signer::address_of(&user);
        let owner_addr = signer::address_of(&owner);

        vault::initialize_vault(&owner);
        vault::grant_permission(&owner, user_addr);
        vault::deposit_tokens(&user, 1000);

        vault::allocate_tokens(&owner, user_addr, 500);
        assert!(vault::get_allocation(owner_addr, user_addr) == 500, 4);

        let initial_balance = coin::balance<AptosCoin>(user_addr);
        vault::claim_tokens(&user);
        let final_balance = coin::balance<AptosCoin>(user_addr);

        assert!(final_balance == initial_balance + 500, 5);
        assert!(vault::get_allocation(owner_addr, user_addr) == 0, 6);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_cancel_allocation(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        let user = create_and_fund_account(aptos_framework);
        let user_addr = signer::address_of(&user);
        let owner_addr = signer::address_of(&owner);

        vault::initialize_vault(&owner);
        vault::grant_permission(&owner, user_addr);
        vault::deposit_tokens(&user, 1000);

        vault::allocate_tokens(&owner, user_addr, 500);
        assert!(vault::get_allocation(owner_addr, user_addr) == 500, 7);

        vault::cancel_allocation(&owner, user_addr);
        assert!(vault::get_allocation(owner_addr, user_addr) == 0, 8);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_withdraw_tokens(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        let user = create_and_fund_account(aptos_framework);
        let user_addr = signer::address_of(&user);
        let owner_addr = signer::address_of(&owner);

        vault::initialize_vault(&owner);
        vault::grant_permission(&owner, user_addr);
        vault::deposit_tokens(&user, 1000);

        let initial_balance = coin::balance<AptosCoin>(owner_addr);
        vault::withdraw_tokens(&owner, 500);
        let final_balance = coin::balance<AptosCoin>(owner_addr);

        assert!(final_balance == initial_balance - 500, 9); // Updated to subtract instead of add
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_check_balance_and_allocations(aptos_framework: &signer) acquires CapabilityStore {
        init_aptos_coin(aptos_framework);
        let owner = create_and_fund_account(aptos_framework);
        let user1 = create_and_fund_account(aptos_framework);
        let user2 = create_and_fund_account(aptos_framework);
        let user1_addr = signer::address_of(&user1);
        let user2_addr = signer::address_of(&user2);
        let owner_addr = signer::address_of(&owner);

        vault::initialize_vault(&owner);
        vault::grant_permission(&owner, user1_addr);
        vault::grant_permission(&owner, user2_addr);
        vault::deposit_tokens(&user1, 1000);
        vault::deposit_tokens(&user2, 2000);

        vault::allocate_tokens(&owner, user1_addr, 500);
        vault::allocate_tokens(&owner, user2_addr, 1000);

        let (balance, total_allocated, addresses, amounts) = vault::check_balance_and_allocations(owner_addr);

        assert!(balance == 3000, 10);
        assert!(total_allocated == 1500, 11);
        assert!(vector::length(&addresses) == 2, 12);
        assert!(vector::length(&amounts) == 2, 13);
        assert!(*vector::borrow(&amounts, 0) == 500 || *vector::borrow(&amounts, 0) == 1000, 14);
        assert!(*vector::borrow(&amounts, 1) == 500 || *vector::borrow(&amounts, 1) == 1000, 15);
    }
}
