#[cfg(test)]
mod tests {
    use super::AnonymousNFT::AnonymousNFT;
    use super::AnonymousNFT::IZKVerifierDispatcher;
    use super::AnonymousNFT::IZKVerifierDispatcherTrait;
    use AnonymousNFT::AnonymousNFT::IZKVerifier; // Import the IZKVerifier trait
    use starknet::{ContractAddress, contract_address_const};
    use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait, DeclareResultTrait }; // Import DeclareResultTrait

    fn deploy_anonymous_nft(admin: ContractAddress, verifier: ContractAddress) -> (IZKVerifierDispatcher, ContractAddress) {
        let contract = declare("AnonymousNFT");
        let mut constructor_calldata = array![admin.into(), verifier.into()];
        
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_calldata)
            .unwrap();

        let dispatcher = IZKVerifierDispatcher { contract_address };
        (dispatcher, contract_address)
    }

    #[test]
    fn test_mint_anonymous() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let verifier: ContractAddress = contract_address_const::<'verifier'>();
        let (anonymous_nft_dispatcher, anonymous_nft_address) = deploy_anonymous_nft(admin, verifier);

        let commitment: felt252 = 123;
        let proof: Array<felt252> = array![1, 2, 3];

        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::mint_anonymous(anonymous_nft_dispatcher, commitment, proof);
        stop_cheat_caller_address(anonymous_nft_address);

        assert(AnonymousNFT::AnonymousNFT::commitment_exists(anonymous_nft_dispatcher, commitment), 'Commitment should exist');
    }

    #[test]
    fn test_transfer_anonymous() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let verifier: ContractAddress = contract_address_const::<'verifier'>();
        let (anonymous_nft_dispatcher, anonymous_nft_address) = deploy_anonymous_nft(admin, verifier);

        let commitment: felt252 = 123;
        let proof: Array<felt252> = array![1, 2, 3];
        let new_owner: ContractAddress = contract_address_const::<'new_owner'>();

        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::mint_anonymous(anonymous_nft_dispatcher, commitment, proof);
        stop_cheat_caller_address(anonymous_nft_address);

        let ownership_proof: Array<felt252> = array![4, 5, 6];
        
        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::transfer_anonymous(anonymous_nft_dispatcher, commitment, new_owner, ownership_proof);
        stop_cheat_caller_address(anonymous_nft_address);

        assert(AnonymousNFT::AnonymousNFT::get_owner(anonymous_nft_dispatcher, commitment) == new_owner, 'Owner should be updated');
    }

    #[test]
    fn test_burn_anonymous() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let verifier: ContractAddress = contract_address_const::<'verifier'>();
        let (anonymous_nft_dispatcher, anonymous_nft_address) = deploy_anonymous_nft(admin, verifier);

        let commitment: felt252 = 123;
        let proof: Array<felt252> = array![1, 2, 3];

        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::mint_anonymous(anonymous_nft_dispatcher, commitment, proof);
        stop_cheat_caller_address(anonymous_nft_address);

        let ownership_proof: Array<felt252> = array![4, 5, 6];
        
        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::burn_anonymous(anonymous_nft_dispatcher, commitment, ownership_proof);
        stop_cheat_caller_address(anonymous_nft_address);

        assert(!AnonymousNFT::AnonymousNFT::commitment_exists(anonymous_nft_dispatcher, commitment), 'Commitment should not exist');
    }

    #[test]
    fn test_set_admin() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let verifier: ContractAddress = contract_address_const::<'verifier'>();
        let (anonymous_nft_dispatcher, anonymous_nft_address) = deploy_anonymous_nft(admin, verifier);
        let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::set_admin(anonymous_nft_dispatcher, new_admin);
        stop_cheat_caller_address(anonymous_nft_address);

        assert(AnonymousNFT::AnonymousNFT::get_admin(anonymous_nft_dispatcher) == new_admin, 'Admin should be updated');
    }

    #[test]
    fn test_set_verifier() {
        let admin: ContractAddress = contract_address_const::<'admin'>();
        let verifier: ContractAddress = contract_address_const::<'verifier'>();
        let (anonymous_nft_dispatcher, anonymous_nft_address) = deploy_anonymous_nft(admin, verifier);
        let new_verifier: ContractAddress = contract_address_const::<'new_verifier'>();

        start_cheat_caller_address(anonymous_nft_address, admin);
        AnonymousNFT::IZKVerifierDispatcherTrait::set_verifier(anonymous_nft_dispatcher, new_verifier);
        stop_cheat_caller_address(anonymous_nft_address);

        assert(AnonymousNFT::AnonymousNFT::get_verifier(anonymous_nft_dispatcher) == new_verifier, 'Verifier should be updated');
    }
}