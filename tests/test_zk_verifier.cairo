use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank};
use starknet::{ContractAddress, contract_address_const};
use private_marketplace::zk_verifier::IZKVerifierDispatcher;
use private_marketplace::zk_verifier::IZKVerifierDispatcherTrait;
use array::ArrayTrait;

// Test Constants
const ADMIN_ADDRESS: felt252 = 0x123;
const USER_ADDRESS: felt252 = 0x456;
const SAMPLE_COMMITMENT: felt252 = 0x111;

#[test]
fn test_verifier_deployment() {
    // Deploy the ZK Verifier contract
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut calldata = ArrayTrait::new();
    calldata.append(admin.into());
    
    let verifier_deployment = verifier_class.deploy(@calldata).unwrap();
    let verifier_address = verifier_deployment.contract_address;
    
    // Create dispatcher
    let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
    
    // Verify admin is set correctly
    assert(verifier_dispatcher.get_admin() == admin, 'Admin not set correctly');
}

#[test]
fn test_proof_verification() {
    // Deploy the ZK Verifier contract
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut calldata = ArrayTrait::new();
    calldata.append(admin.into());

    let verifier_deployment = verifier_class.deploy(@calldata).unwrap();
    let verifier_address = verifier_deployment.contract_address;
    
    // Create dispatcher
    let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
    
    // Test the proof verification
    let mut proof = ArrayTrait::new();
    proof.append(0x1); // Dummy proof
    
    let result = verifier_dispatcher.verify_proof(proof);
    assert(result == 1, 'Proof should be valid');
}

#[test]
fn test_ownership_verification() {
    // Deploy the ZK Verifier contract
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut calldata = ArrayTrait::new();
    calldata.append(admin.into());

    let verifier_deployment = verifier_class.deploy(@calldata).unwrap();
    let verifier_address = verifier_deployment.contract_address;
    
    // Create dispatcher
    let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
    
    // Test ownership verification
    let mut proof = ArrayTrait::new();
    proof.append(0x2); // Dummy proof
    
    let result = verifier_dispatcher.verify_ownership(SAMPLE_COMMITMENT, proof);
    assert(result == 1, 'Ownership proof should be valid');
}

#[test]
fn test_admin_change() {
    // Deploy the ZK Verifier contract
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut calldata = ArrayTrait::new();
    calldata.append(admin.into());

   let verifier_deployment = verifier_class.deploy(@calldata).unwrap();
    let verifier_address = verifier_deployment.contract_address;
    
    // Create dispatcher
    let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
    
    // Set admin as caller
    start_prank(verifier_address, admin);
    
    // Test changing admin
    let new_admin: ContractAddress = contract_address_const::<USER_ADDRESS>();
    verifier_dispatcher.set_admin(new_admin);
    
    assert(verifier_dispatcher.get_admin() == new_admin, 'Admin change failed');
    
    stop_prank(verifier_address);
}

#[test]
#[should_panic(expected: ('Only admin can change admin',))]
fn test_unauthorized_admin_change() {
    // Deploy the ZK Verifier contract
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut calldata = ArrayTrait::new();
    calldata.append(admin.into());
    
    let verifier_deployment = verifier_class.deploy(@calldata).unwrap();
    let verifier_address = verifier_deployment.contract_address;
    // Create dispatcher
    let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
    
    // Set non-admin as caller
    let user: ContractAddress = contract_address_const::<USER_ADDRESS>();
    start_prank(verifier_address, user);
    
    // Try to change admin (should fail)
    let new_admin: ContractAddress = contract_address_const::<USER_ADDRESS>();
    verifier_dispatcher.set_admin(new_admin);  // This should panic
    
    stop_prank(verifier_address);
}