use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_prank, stop_prank};
use starknet::{ContractAddress, contract_address_const};
use private_marketplace::anonymous_nft::IAnonymousNFTDispatcher;
use private_marketplace::anonymous_nft::IAnonymousNFTDispatcherTrait;

use array::ArrayTrait;

// Test Constants
const ADMIN_ADDRESS: felt252 = 0x123;
const USER1_ADDRESS: felt252 = 0x456;
const USER2_ADDRESS: felt252 = 0x789;
const SAMPLE_COMMITMENT: felt252 = 0x111;

#[test]
fn test_nft_deployment_and_configuration() {
    // Deploy ZKVerifier contract
    let verifier_class = declare("ZKVerifier").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    let verifier_calldata = array![admin.into()];
    let (verifier_address, _) = verifier_class.deploy(@verifier_calldata).unwrap();

    // Deploy AnonymousNFT contract
    let nft_class = declare("AnonymousNFT").unwrap().contract_class();
    let nft_calldata = array![admin.into(), verifier_address.into()];
    let (nft_address, _) = nft_class.deploy(@nft_calldata).unwrap();

    // Create dispatcher
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };

    // Verify configuration
    assert(nft_dispatcher.get_admin() == admin, 'Admin not set correctly');
    assert(nft_dispatcher.get_verifier() == verifier_address, 'Verifier not set correctly');
    assert(nft_dispatcher.get_total_supply() == 0, 'Initial supply not zero');
}

#[test]
fn test_minting() {
    // Deploy required contracts first
    let verifier_class = declare("ZKVerifier").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    let verifier_calldata = array![admin.into()];
    let (verifier_address, _) = verifier_class.deploy(@verifier_calldata).unwrap();

    let nft_class = declare("AnonymousNFT").unwrap().contract_class();
    let nft_calldata = array![admin.into(), verifier_address.into()];
    let (nft_address, _) = nft_class.deploy(@nft_calldata).unwrap();

    // Create dispatcher
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };

    // User mints an NFT
    let user1: ContractAddress = contract_address_const::<USER1_ADDRESS>();
    start_prank(nft_address, user1);

    let mut mint_proof = ArrayTrait::new();
    mint_proof.append(0x1); // Dummy proof

    nft_dispatcher.mint_anonymous(SAMPLE_COMMITMENT, mint_proof.span());

    // Verify minting worked
    assert(nft_dispatcher.commitment_exists(SAMPLE_COMMITMENT), 'Commitment should exist');
    assert(nft_dispatcher.get_owner(SAMPLE_COMMITMENT) == user1, 'Owner should be user1');
    assert(nft_dispatcher.get_owner_commitment_count(user1) == 1, 'Should have 1 NFT');
    assert(nft_dispatcher.get_total_supply() == 1, 'Total supply should be 1');

    stop_prank(nft_address);
}

#[test]
fn test_transfer() {
    // Deploy required contracts first
    let verifier_class = declare("ZKVerifier").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    let verifier_calldata = array![admin.into()];
    let (verifier_address, _) = verifier_class.deploy(@verifier_calldata).unwrap();

    let nft_class = declare("AnonymousNFT").unwrap().contract_class();
    let nft_calldata = array![admin.into(), verifier_address.into()];
    let (nft_address, _) = nft_class.deploy(@nft_calldata).unwrap();

    // Create dispatcher
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };

    // User1 mints an NFT
    let user1: ContractAddress = contract_address_const::<USER1_ADDRESS>();
    start_prank(nft_address, user1);

    let mut mint_proof = ArrayTrait::new();
    mint_proof.append(0x1); // Dummy proof

    nft_dispatcher.mint_anonymous(SAMPLE_COMMITMENT, mint_proof.span());

    // Verify initial state
    assert(nft_dispatcher.get_owner(SAMPLE_COMMITMENT) == user1, 'Owner should be user1');

    // User1 transfers to User2
    let user2: ContractAddress = contract_address_const::<USER2_ADDRESS>();

    let mut transfer_proof = ArrayTrait::new();
    transfer_proof.append(0x2); // Dummy proof

    nft_dispatcher.transfer_anonymous(SAMPLE_COMMITMENT, user2, transfer_proof.span());

    // Verify transfer
    assert(nft_dispatcher.get_owner(SAMPLE_COMMITMENT) == user2, 'New owner should be user2');
    assert(nft_dispatcher.get_owner_commitment_count(user1) == 0, 'User1 should have 0 NFTs');
    assert(nft_dispatcher.get_owner_commitment_count(user2) == 1, 'User2 should have 1 NFT');

    stop_prank(nft_address);
}

#[test]
fn test_burning() {
    // Deploy required contracts first
    let verifier_class = declare("ZKVerifier").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    let verifier_calldata = array![admin.into()];
    let (verifier_address, _) = verifier_class.deploy(@verifier_calldata).unwrap();

    let nft_class = declare("AnonymousNFT").unwrap().contract_class();
    let nft_calldata = array![admin.into(), verifier_address.into()];
    let (nft_address, _) = nft_class.deploy(@nft_calldata).unwrap();

    // Create dispatcher
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };

    // User1 mints an NFT
    let user1: ContractAddress = contract_address_const::<USER1_ADDRESS>();
    start_prank(nft_address, user1);

    let mut mint_proof = ArrayTrait::new();
    mint_proof.append(0x1); // Dummy proof

    nft_dispatcher.mint_anonymous(SAMPLE_COMMITMENT, mint_proof.span());

    // Verify initial state
    assert(nft_dispatcher.commitment_exists(SAMPLE_COMMITMENT), 'Commitment should exist');
    assert(nft_dispatcher.get_total_supply() == 1, 'Total supply should be 1');

    // User1 burns the NFT
    let mut burn_proof = ArrayTrait::new();
    burn_proof.append(0x3); // Dummy proof

    nft_dispatcher.burn_anonymous(SAMPLE_COMMITMENT, burn_proof.span());

    // Verify burning
    assert(!nft_dispatcher.commitment_exists(SAMPLE_COMMITMENT), 'Commitment should not exist');
    assert(nft_dispatcher.get_owner_commitment_count(user1) == 0, 'User1 should have 0 NFTs');
    assert(nft_dispatcher.get_total_supply() == 0, 'Total supply should be 0');

    stop_prank(nft_address);
}

#[test]
fn test_admin_functions() {
    // Deploy required contracts first
    let verifier_class = declare("ZKVerifier").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    let verifier_calldata = array![admin.into()];
    let (verifier_address, _) = verifier_class.deploy(@verifier_calldata).unwrap();

    let nft_class = declare("AnonymousNFT").unwrap().contract_class();
    let nft_calldata = array![admin.into(), verifier_address.into()];
    let (nft_address, _) = nft_class.deploy(@nft_calldata).unwrap();

    // Create dispatcher
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };

    // Set admin as caller
    start_prank(nft_address, admin);

    // Test changing admin
    let new_admin: ContractAddress = contract_address_const::<USER1_ADDRESS>();
    nft_dispatcher.set_admin(new_admin);

    assert(nft_dispatcher.get_admin() == new_admin, 'Admin change failed');

    // Test changing verifier
    let new_verifier_class = declare("ZKVerifier").unwrap().contract_class();
    let new_verifier_calldata = array![admin.into()];
    let (new_verifier_address, _) = new_verifier_class.deploy(@new_verifier_calldata).unwrap();

    nft_dispatcher.set_verifier(new_verifier_address);

    assert(nft_dispatcher.get_verifier() == new_verifier_address, 'Verifier change failed');

    stop_prank(nft_address);
}