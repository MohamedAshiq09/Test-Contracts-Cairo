mod anonymous_nft {
    use starknet::ContractAddress;

    #[starknet::interface]
    pub trait IAnonymousNFT<TContractState> {
        fn mint_anonymous(ref self: TContractState, commitment: felt252, proof: Array<felt252>);
        fn transfer_anonymous(
            ref self: TContractState, 
            commitment: felt252, 
            new_owner: ContractAddress,
            ownership_proof: Array<felt252>
        );
        fn burn_anonymous(ref self: TContractState, commitment: felt252, ownership_proof: Array<felt252>);
        fn get_owner(self: @TContractState, commitment: felt252) -> ContractAddress;
        fn commitment_exists(self: @TContractState, commitment: felt252) -> bool;
        fn get_owner_commitment_count(self: @TContractState, owner: ContractAddress) -> u256;
        fn get_total_supply(self: @TContractState) -> u256;
        fn get_admin(self: @TContractState) -> ContractAddress;
        fn set_admin(ref self: TContractState, new_admin: ContractAddress);
    }
}

mod marketplace {
    use starknet::ContractAddress;

    #[derive(Drop, Serde, starknet::Event)]
    pub struct Listing {
        pub token_id: felt252,
        pub price: felt252,
        pub commitment: felt252,
        pub seller: ContractAddress,
        pub expiration: u64,
        pub active: bool,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct Offer {
        pub listing_id: felt252,
        pub buyer: ContractAddress,
        pub offer_price: felt252,
        pub expiration: u64,
    }

    #[starknet::interface]
    pub trait IMarketPlace<TContractState> {
        // View functions
        fn get_listing(self: @TContractState, listing_id: felt252) -> Listing;
        fn is_token_sold(self: @TContractState, token_id: felt252) -> bool;
        fn get_platform_fee(self: @TContractState) -> (u16, ContractAddress);
        fn get_offer(self: @TContractState, listing_id: felt252, buyer: ContractAddress) -> Offer;
        fn get_token_royalty(self: @TContractState, token_id: felt252) -> (ContractAddress, u16);
        fn is_collection_approved(self: @TContractState, collection_address: ContractAddress) -> bool;
        fn get_admin(self: @TContractState) -> ContractAddress;

        // External functions
        fn list_nft(
            ref self: TContractState,
            token_id: felt252,
            price: felt252,
            expiration: u64,
            proof: Array<felt252>
        ) -> felt252;
        
        fn update_listing(
            ref self: TContractState,
            listing_id: felt252,
            new_price: felt252,
            new_expiration: u64
        );
        
        fn cancel_listing(ref self: TContractState, listing_id: felt252);
        
        fn purchase(ref self: TContractState, listing_id: felt252, proof: Array<felt252>);
        
        fn make_offer(
            ref self: TContractState,
            listing_id: felt252,
            offer_price: felt252,
            expiration: u64
        );
        
        fn accept_offer(
            ref self: TContractState,
            listing_id: felt252,
            buyer: ContractAddress
        );
        
        fn set_platform_fee(ref self: TContractState, new_fee_percentage: u16);
        
        fn set_platform_fee_recipient(ref self: TContractState, new_recipient: ContractAddress);
        
        fn set_token_royalty(
            ref self: TContractState,
            token_id: felt252,
            recipient: ContractAddress,
            royalty_percentage: u16
        );
        
        fn approve_collection(
            ref self: TContractState,
            collection_address: ContractAddress,
            approved: bool
        );
    }
}