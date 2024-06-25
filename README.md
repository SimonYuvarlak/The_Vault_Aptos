# Aptos Vault Contract

## Overview

This project implements a secure and flexible vault system on the Aptos blockchain. The vault allows for permissioned deposits, admin-controlled allocations, and secure withdrawals. It's designed to manage and distribute tokens in a controlled manner, suitable for various use cases such as team token vesting, reward distribution, or managed fund allocation.

## Features

- **Permissioned Deposits**: Only authorized addresses can deposit tokens into the vault.
- **Admin-Controlled Allocations**: The admin can allocate tokens to specific addresses.
- **Secure Withdrawals**: Users can claim their allocated tokens securely.
- **Admin Withdrawals**: The admin can withdraw unallocated tokens.
- **Permission Management**: The admin can grant or revoke deposit permissions.
- **Allocation Management**: The admin can create, modify, or cancel token allocations.
- **Admin Transferability**: The admin role can be transferred to a new address.
- **Event Emissions**: All major actions emit events for off-chain tracking.

## Smart Contract Structure

The main components of the contract are:

- `Vault`: The core struct that holds the vault's data and logic.
- `VaultSignerCapability`: A struct that holds the capability to sign transactions on behalf of the vault.

Key functions include:

- `init_module`: Initializes the vault when the module is published.
- `deposit_tokens`: Allows permissioned addresses to deposit tokens.
- `allocate_tokens`: Allows the admin to allocate tokens to addresses.
- `claim_tokens`: Allows users to claim their allocated tokens.
- `withdraw_tokens`: Allows the admin to withdraw unallocated tokens.
- `change_admin`: Allows transferring the admin role to a new address.

## Setup and Deployment

1. Ensure you have the Aptos CLI installed and configured.
2. Clone this repository:
   ```
   git clone <repository-url>
   cd aptos-vault-contract
   ```
3. Compile the contract:
   ```
   aptos move compile
   ```
4. Deploy the contract to the Aptos blockchain:
   ```
   aptos move publish
   ```
