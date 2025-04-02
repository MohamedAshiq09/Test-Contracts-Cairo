#[cfg(test)]
mod tests {
    use super::ZKVerifier;
    use super::ZKVerifier::IZKVerifierDispatcher;
    use super::ZKVerifier::IZKVerifierDispatcherTrait;
    use starknet::{ContractAddress, contract_address_const};
    use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address };

    fn deploy_zk_verifier(admin: ContractAddress) -> (IZKVerifierDispatcher, ContractAddress) {
        let contract = declare("ZKVerifier");
        let mut constructor_calldata = array![admin.into()];
        
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_calldata)
            .unwrap();

        let dispatcher = IZKVerifierDispatcher { contract_address };
        (dispatcher, contract_address)
    }

    #[test]
    fn test_verify_proof() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let (zk_verifier_dispatcher, zk_verifier_address) = deploy_zk_verifier(admin);

        let proof: Array<felt252> = array![1, 2, 3];

        start_cheat_caller_address(zk_verifier_address, admin);
        let is_valid = zk_verifier_dispatcher.verify_proof(proof);
        stop_cheat_caller_address(zk_verifier_address);

        assert(is_valid == 1, 'Proof should be valid');
    }

    #[test]
    fn test_verify_ownership() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let (zk_verifier_dispatcher, zk_verifier_address) = deploy_zk_verifier(admin);

        let commitment: felt252 = 123;
        let proof: Array<felt252> = array![1, 2, 3];

        start_cheat_caller_address(zk_verifier_address, admin);
        let is_valid = zk_verifier_dispatcher.verify_ownership(commitment, proof);
        stop_cheat_caller_address(zk_verifier_address);

        assert(is_valid == 1, 'Ownership should be valid');
    }

    #[test]
    fn test_set_admin() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let (zk_verifier_dispatcher, zk_verifier_address) = deploy_zk_verifier(admin);
        let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

        start_cheat_caller_address(zk_verifier_address, admin);
        zk_verifier_dispatcher.set_admin(new_admin);
        stop_cheat_caller_address(zk_verifier_address);

        assert(zk_verifier_dispatcher.get_admin() == new_admin, 'Admin should be updated');
    }
}