#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::syscalls::deploy_syscall;
    use array::ArrayTrait;
    use result::ResultTrait;
    use option::OptionTrait;
    use traits::TryInto;
    use box::BoxTrait;
    use zeroable::Zeroable;
    use integer::u256;
    use integer::u256_from_felt252;
    use snforge_std as snforge;
    use snforge_std::{start_prank, stop_prank, declare, ContractClassTrait};

    // Import the contract interfaces
    use anonymous_nft::IAnonymousNFTDispatcher;
    use anonymous_nft::IAnonymousNFTDispatcherTrait;
    use marketplace::IMarketPlaceDispatcher;
    use marketplace::IMarketPlaceDispatcherTrait;
    use zk_verifier::IZKVerifierDispatcher;
    use zk_verifier::IZKVerifierDispatcherTrait;

    // Helper to convert felt252 to ContractAddress
    fn felt_to_address(felt: felt252) -> ContractAddress {
        felt.try_into().unwrap()
    }

    // Test Constants
    const ADMIN: felt252 = 'admin';
    const USER1: felt252 = 'user1';
    const USER2: felt252 = 'user2';
    const PLATFORM_FEE_RECIPIENT: felt252 = 'fee_recipient';
    const ZERO: felt252 = 0;
    const PLATFORM_FEE: u16 = 250; // 2.5%
    
    // Helper to create a mock ZK proof array
    fn create_mock_proof() -> Array<felt252> {
        let mut proof = ArrayTrait::new();
        proof.append('proof_element_1');
        proof.append('proof_element_2');
        proof.append('proof_element_3');
        proof
    }

    #[test]
    fn test_zk_verifier_deployment() {
        // 1. Declare the contract
        let contract = declare("ZKVerifier");
        
        // 2. Prepare constructor arguments
        let mut constructor_args = ArrayTrait::new();
        constructor_args.append(ADMIN);

        // 3. Deploy the contract
        let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let verifier = IZKVerifierDispatcher { contract_address };
        
        // 5. Test the admin setting
        assert(verifier.get_admin() == felt_to_address(ADMIN), 'Admin not set correctly');
    }

    #[test]
    fn test_zk_verifier_proof_verification() {
        // 1. Declare the contract
        let contract = declare("ZKVerifier");
        
        // 2. Prepare constructor arguments
        let mut constructor_args = ArrayTrait::new();
        constructor_args.append(ADMIN);

        // 3. Deploy the contract
        let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let verifier = IZKVerifierDispatcher { contract_address };
        
        // 5. Test proof verification
        let proof = create_mock_proof();
        assert(verifier.verify_proof(proof) == 1, 'Proof verification failed');
    }

    #[test]
    fn test_zk_verifier_ownership_verification() {
        // 1. Declare the contract
        let contract = declare("ZKVerifier");
        
        // 2. Prepare constructor arguments
        let mut constructor_args = ArrayTrait::new();
        constructor_args.append(ADMIN);

        // 3. Deploy the contract
        let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let verifier = IZKVerifierDispatcher { contract_address };
        
        // 5. Test ownership verification
        let proof = create_mock_proof();
        let commitment = 'test_commitment';
        assert(verifier.verify_ownership(commitment, proof) == 1, 'Ownership verification failed');
    }

    #[test]
    fn test_zk_verifier_admin_change() {
        // 1. Declare the contract
        let contract = declare("ZKVerifier");
        
        // 2. Prepare constructor arguments
        let mut constructor_args = ArrayTrait::new();
        constructor_args.append(ADMIN);

        // 3. Deploy the contract
        let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let verifier = IZKVerifierDispatcher { contract_address };
        
        // 5. Test admin change with non-admin (should fail)
        start_prank(contract_address, felt_to_address(USER1));
        // This should panic with the error message "Only admin can change admin"
        match snforge::try_with_error(|| {
            verifier.set_admin(felt_to_address(USER1));
        }) {
            Option::Some(message) => {
                assert(message == 'Only admin can change admin', 'Wrong error message');
            },
            Option::None => {
                panic_with_felt252('Should have failed with non-admin');
            }
        }
        stop_prank(contract_address);
        
        // 6. Test admin change with admin (should succeed)
        start_prank(contract_address, felt_to_address(ADMIN));
        verifier.set_admin(felt_to_address(USER1));
        stop_prank(contract_address);
        
        // 7. Verify admin change
        assert(verifier.get_admin() == felt_to_address(USER1), 'Admin not changed correctly');
    }

    #[test]
    fn test_anonymous_nft_deployment() {
        // 1. First declare and deploy the ZKVerifier
        let verifier_contract = declare("ZKVerifier");
        let mut verifier_args = ArrayTrait::new();
        verifier_args.append(ADMIN);
        let (verifier_address, _) = verifier_contract.deploy(@verifier_args).unwrap();
        
        // 2. Declare the AnonymousNFT contract
        let nft_contract = declare("AnonymousNFT");
        
        // 3. Prepare constructor arguments for NFT
        let mut nft_args = ArrayTrait::new();
        nft_args.append(ADMIN);
        nft_args.append(verifier_address.into());

        // 4. Deploy the NFT contract
        let (nft_address, _) = nft_contract.deploy(@nft_args).unwrap();
        
        // 5. Create a dispatcher to interact with the contract
        let nft = IAnonymousNFTDispatcher { contract_address: nft_address };
        
        // 6. Test the admin and verifier settings
        assert(nft.get_admin() == felt_to_address(ADMIN), 'Admin not set correctly');
        assert(nft.get_verifier() == verifier_address, 'Verifier not set correctly');
        assert(nft.get_total_supply() == u256_from_felt252(0), 'Initial supply not zero');
    }

    #[test]
    fn test_anonymous_nft_mint() {
        // 1. First declare and deploy the ZKVerifier
        let verifier_contract = declare("ZKVerifier");
        let mut verifier_args = ArrayTrait::new();
        verifier_args.append(ADMIN);
        let (verifier_address, _) = verifier_contract.deploy(@verifier_args).unwrap();
        
        // 2. Declare the AnonymousNFT contract
        let nft_contract = declare("AnonymousNFT");
        
        // 3. Prepare constructor arguments for NFT
        let mut nft_args = ArrayTrait::new();
        nft_args.append(ADMIN);
        nft_args.append(verifier_address.into());

        // 4. Deploy the NFT contract
        let (nft_address, _) = nft_contract.deploy(@nft_args).unwrap();
        
        // 5. Create dispatchers to interact with both contracts
        let nft = IAnonymousNFTDispatcher { contract_address: nft_address };
        let verifier = IZKVerifierDispatcher { contract_address: verifier_address };
        
        // 6. Test minting
        start_prank(nft_address, felt_to_address(USER1));
        
        let commitment = 'test_commitment';
        let proof = create_mock_proof();
        
        // Mint the NFT
        nft.mint_anonymous(commitment, proof);
        
        // Check if NFT was minted
        assert(nft.commitment_exists(commitment), 'Commitment does not exist');
        assert(nft.get_owner(commitment) == felt_to_address(USER1), 'Wrong owner');
        assert(nft.get_owner_commitment_count(felt_to_address(USER1)) == u256_from_felt252(1), 'Wrong commitment count');
        assert(nft.get_total_supply() == u256_from_felt252(1), 'Wrong total supply');
        
        stop_prank(nft_address);
    }

    #[test]
    fn test_anonymous_nft_transfer() {
        // 1. First declare and deploy the ZKVerifier
        let verifier_contract = declare("ZKVerifier");
        let mut verifier_args = ArrayTrait::new();
        verifier_args.append(ADMIN);
        let (verifier_address, _) = verifier_contract.deploy(@verifier_args).unwrap();
        
        // 2. Declare the AnonymousNFT contract
        let nft_contract = declare("AnonymousNFT");
        
        // 3. Prepare constructor arguments for NFT
        let mut nft_args = ArrayTrait::new();
        nft_args.append(ADMIN);
        nft_args.append(verifier_address.into());

        // 4. Deploy the NFT contract
        let (nft_address, _) = nft_contract.deploy(@nft_args).unwrap();
        
        // 5. Create dispatchers to interact with both contracts
        let nft = IAnonymousNFTDispatcher { contract_address: nft_address };
        
        // 6. Mint an NFT as USER1
        start_prank(nft_address, felt_to_address(USER1));
        let commitment = 'test_commitment';
        let proof = create_mock_proof();
        nft.mint_anonymous(commitment, proof);
        stop_prank(nft_address);
        
        // 7. Transfer the NFT from USER1 to USER2
        start_prank(nft_address, felt_to_address(USER1));
        nft.transfer_anonymous(commitment, felt_to_address(USER2), proof);
        stop_prank(nft_address);
        
        // 8. Check transfer results
        assert(nft.commitment_exists(commitment), 'Commitment does not exist');
        assert(nft.get_owner(commitment) == felt_to_address(USER2), 'Transfer failed');
        assert(nft.get_owner_commitment_count(felt_to_address(USER1)) == u256_from_felt252(0), 'USER1 count wrong');
        assert(nft.get_owner_commitment_count(felt_to_address(USER2)) == u256_from_felt252(1), 'USER2 count wrong');
        assert(nft.get_total_supply() == u256_from_felt252(1), 'Wrong total supply');
    }

    #[test]
    fn test_anonymous_nft_burn() {
        // 1. First declare and deploy the ZKVerifier
        let verifier_contract = declare("ZKVerifier");
        let mut verifier_args = ArrayTrait::new();
        verifier_args.append(ADMIN);
        let (verifier_address, _) = verifier_contract.deploy(@verifier_args).unwrap();
        
        // 2. Declare the AnonymousNFT contract
        let nft_contract = declare("AnonymousNFT");
        
        // 3. Prepare constructor arguments for NFT
        let mut nft_args = ArrayTrait::new();
        nft_args.append(ADMIN);
        nft_args.append(verifier_address.into());

        // 4. Deploy the NFT contract
        let (nft_address, _) = nft_contract.deploy(@nft_args).unwrap();
        
        // 5. Create dispatchers to interact with both contracts
        let nft = IAnonymousNFTDispatcher { contract_address: nft_address };
        
        // 6. Mint an NFT as USER1
        start_prank(nft_address, felt_to_address(USER1));
        let commitment = 'test_commitment';
        let proof = create_mock_proof();
        nft.mint_anonymous(commitment, proof);
        
        // 7. Burn the NFT
        nft.burn_anonymous(commitment, proof);
        stop_prank(nft_address);
        
        // 8. Check burn results
        assert(!nft.commitment_exists(commitment), 'Commitment still exists');
        assert(nft.get_owner(commitment).is_zero(), 'Owner not zero');
        assert(nft.get_owner_commitment_count(felt_to_address(USER1)) == u256_from_felt252(0), 'Count not zero');
        assert(nft.get_total_supply() == u256_from_felt252(0), 'Supply not zero');
    }

    #[test]
    fn test_marketplace_deployment() {
        // 1. Declare the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        
        // 2. Prepare constructor arguments
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);

        // 3. Deploy the contract
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. Test the initial settings
        let (fee, recipient) = marketplace.get_platform_fee();
        assert(fee == PLATFORM_FEE, 'Fee not set correctly');
        assert(recipient == felt_to_address(PLATFORM_FEE_RECIPIENT), 'Recipient not set correctly');
        assert(marketplace.get_admin() == felt_to_address(PLATFORM_FEE_RECIPIENT), 'Admin not set correctly');
    }

    #[test]
    fn test_marketplace_listing() {
        // 1. Declare the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        
        // 2. Prepare constructor arguments
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);

        // 3. Deploy the contract
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. List an NFT
        start_prank(marketplace_address, felt_to_address(USER1));
        let token_id = 'token1';
        let price = 1000;
        let expiration = 86400; // 1 day
        let proof = create_mock_proof();
        
        let listing_id = marketplace.list_nft(token_id, price, expiration, proof);
        stop_prank(marketplace_address);
        
        // 6. Check the listing
        let listing = marketplace.get_listing(listing_id);
        assert(listing.token_id == token_id, 'Token ID mismatch');
        assert(listing.price == price, 'Price mismatch');
        assert(listing.seller == felt_to_address(USER1), 'Seller mismatch');
        assert(listing.active, 'Listing not active');
    }

    #[test]
    fn test_marketplace_update_listing() {
        // 1. Declare the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        
        // 2. Prepare constructor arguments
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);

        // 3. Deploy the contract
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. List an NFT
        start_prank(marketplace_address, felt_to_address(USER1));
        let token_id = 'token1';
        let price = 1000;
        let expiration = 86400; // 1 day
        let proof = create_mock_proof();
        
        let listing_id = marketplace.list_nft(token_id, price, expiration, proof);
        
        // 6. Update the listing
        let new_price = 1500;
        let new_expiration = 172800; // 2 days
        marketplace.update_listing(listing_id, new_price, new_expiration);
        stop_prank(marketplace_address);
        
        // 7. Check the updated listing
        let listing = marketplace.get_listing(listing_id);
        assert(listing.price == new_price, 'Price not updated');
        // Note: We can't easily check the expiration time as it depends on block timestamp
    }

    #[test]
    fn test_marketplace_cancel_listing() {
        // 1. Declare the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        
        // 2. Prepare constructor arguments
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);

        // 3. Deploy the contract
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. List an NFT
        start_prank(marketplace_address, felt_to_address(USER1));
        let token_id = 'token1';
        let price = 1000;
        let expiration = 86400; // 1 day
        let proof = create_mock_proof();
        
        let listing_id = marketplace.list_nft(token_id, price, expiration, proof);
        
        // 6. Cancel the listing
        marketplace.cancel_listing(listing_id);
        stop_prank(marketplace_address);
        
        // 7. Check the cancelled listing
        let listing = marketplace.get_listing(listing_id);
        assert(!listing.active, 'Listing still active');
    }

    #[test]
    fn test_marketplace_purchase() {
        // 1. Declare the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        
        // 2. Prepare constructor arguments
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);

        // 3. Deploy the contract
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. List an NFT
        start_prank(marketplace_address, felt_to_address(USER1));
        let token_id = 'token1';
        let price = 1000;
        let expiration = 86400; // 1 day
        let proof = create_mock_proof();
        
        let listing_id = marketplace.list_nft(token_id, price, expiration, proof);
        stop_prank(marketplace_address);
        
        // 6. Purchase the NFT
        start_prank(marketplace_address, felt_to_address(USER2));
        marketplace.purchase(listing_id, proof);
        stop_prank(marketplace_address);
        
        // 7. Check the purchase
        let listing = marketplace.get_listing(listing_id);
        assert(!listing.active, 'Listing still active');
        assert(marketplace.is_token_sold(token_id), 'Token not marked as sold');
    }

    #[test]
    fn test_marketplace_offer() {
        // 1. Declare the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        
        // 2. Prepare constructor arguments
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);

        // 3. Deploy the contract
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create a dispatcher to interact with the contract
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. List an NFT
        start_prank(marketplace_address, felt_to_address(USER1));
        let token_id = 'token1';
        let price = 1000;
        let expiration = 86400; // 1 day
        let proof = create_mock_proof();
        
        let listing_id = marketplace.list_nft(token_id, price, expiration, proof);
        stop_prank(marketplace_address);
        
        // 6. Make an offer
        start_prank(marketplace_address, felt_to_address(USER2));
        let offer_price = 900;
        let offer_expiration = 43200; // 12 hours
        marketplace.make_offer(listing_id, offer_price, offer_expiration);
        stop_prank(marketplace_address);
        
        // 7. Check the offer
        let offer = marketplace.get_offer(listing_id, felt_to_address(USER2));
        assert(offer.listing_id == listing_id, 'Listing ID mismatch');
        assert(offer.buyer == felt_to_address(USER2), 'Buyer mismatch');
        assert(offer.offer_price == offer_price, 'Offer price mismatch');
        
        // 8. Accept the offer
        start_prank(marketplace_address, felt_to_address(USER1));
        marketplace.accept_offer(listing_id, felt_to_address(USER2));
        stop_prank(marketplace_address);
        
        // 9. Check acceptance
        let listing = marketplace.get_listing(listing_id);
        assert(!listing.active, 'Listing still active');
        assert(marketplace.is_token_sold(token_id), 'Token not marked as sold');
    }

    #[test]
    fn test_integration_nft_and_marketplace() {
        // 1. First declare and deploy the ZKVerifier
        let verifier_contract = declare("ZKVerifier");
        let mut verifier_args = ArrayTrait::new();
        verifier_args.append(ADMIN);
        let (verifier_address, _) = verifier_contract.deploy(@verifier_args).unwrap();
        
        // 2. Declare and deploy the AnonymousNFT contract
        let nft_contract = declare("AnonymousNFT");
        let mut nft_args = ArrayTrait::new();
        nft_args.append(ADMIN);
        nft_args.append(verifier_address.into());
        let (nft_address, _) = nft_contract.deploy(@nft_args).unwrap();
        
        // 3. Declare and deploy the MarketPlace contract
        let marketplace_contract = declare("MarketPlace");
        let mut marketplace_args = ArrayTrait::new();
        marketplace_args.append(PLATFORM_FEE);
        marketplace_args.append(PLATFORM_FEE_RECIPIENT);
        let (marketplace_address, _) = marketplace_contract.deploy(@marketplace_args).unwrap();
        
        // 4. Create dispatchers for all contracts
        let nft = IAnonymousNFTDispatcher { contract_address: nft_address };
        let marketplace = IMarketPlaceDispatcher { contract_address: marketplace_address };
        
        // 5. Mint an NFT as USER1
        start_prank(nft_address, felt_to_address(USER1));
        let commitment = 'test_commitment';
        let proof = create_mock_proof();
        nft.mint_anonymous(commitment, proof);
        stop_prank(nft_address);
        
        // 6. Approve marketplace for NFT collection (as admin)
        start_prank(marketplace_address, felt_to_address(PLATFORM_FEE_RECIPIENT));
        marketplace.approve_collection(nft_address, true);
        stop_prank(marketplace_address);
        
        // 7. List the NFT on marketplace
        start_prank(marketplace_address, felt_to_address(USER1));
        let token_id = commitment;
        let price = 1000;
        let expiration = 86400; // 1 day
        let listing_id = marketplace.list_nft(token_id, price, expiration, proof);
        stop_prank(marketplace_address);
        
        // 8. USER2 purchases the NFT
        start_prank(marketplace_address, felt_to_address(USER2));
        marketplace.purchase(listing_id, proof);
        stop_prank(marketplace_address);
        
        // 9. Transfer NFT ownership in the AnonymousNFT contract
        start_prank(nft_address, felt_to_address(USER1));
        nft.transfer_anonymous(commitment, felt_to_address(USER2), proof);
        stop_prank(nft_address);
        
        // 10. Verify everything
        assert(!marketplace.get_listing(listing_id).active, 'Listing still active');
        assert(marketplace.is_token_sold(token_id), 'Token not marked as sold');
        assert(nft.get_owner(commitment) == felt_to_address(USER2), 'NFT transfer failed');
    }
}