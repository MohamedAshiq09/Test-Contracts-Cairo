mod marketplace_structs {
    use starknet::ContractAddress;

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Listing {
        pub token_id: felt252,
        pub price: felt252,
        pub seller: ContractAddress,
        pub expiration: u64,
        pub active: bool,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Offer {
        pub listing_id: felt252,
        pub buyer: ContractAddress,
        pub offer_price: felt252,
        pub expiration: u64,
    }
}


#[starknet::interface]
pub trait IMarketPlace<TContractState> {
    
    fn get_listing(self: @TContractState, listing_id: felt252) -> marketplace_structs::Listing;
    fn is_token_sold(self: @TContractState, token_id: felt252) -> bool;
    fn get_platform_fee(self: @TContractState) -> (u16, starknet::ContractAddress);
    fn get_offer(
        self: @TContractState, 
        listing_id: felt252, 
        buyer: starknet::ContractAddress
    ) -> marketplace_structs::Offer;
    fn get_token_royalty(self: @TContractState, token_id: felt252) -> (starknet::ContractAddress, u16);
    fn is_collection_approved(self: @TContractState, collection_address: starknet::ContractAddress) -> bool;

    
    fn list_nft(
        ref self: TContractState,
        token_id: felt252,
        price: felt252,
        expiration: u64
    ) -> felt252;
    fn update_listing(
        ref self: TContractState,
        listing_id: felt252,
        new_price: felt252,
        new_expiration: u64
    );
    fn cancel_listing(ref self: TContractState, listing_id: felt252);
    fn purchase(ref self: TContractState, listing_id: felt252);
    fn make_offer(
        ref self: TContractState,
        listing_id: felt252,
        offer_price: felt252,
        expiration: u64
    );
    fn accept_offer(
        ref self: TContractState,
        listing_id: felt252,
        buyer: starknet::ContractAddress
    );
    fn set_platform_fee(
        ref self: TContractState,
        new_fee_percentage: u16
    );
    fn set_platform_fee_recipient(
        ref self: TContractState,
        new_recipient: starknet::ContractAddress
    );
    fn set_token_royalty(
        ref self: TContractState,
        token_id: felt252,
        recipient: starknet::ContractAddress,
        royalty_percentage: u16
    );
    fn approve_collection(
        ref self: TContractState,
        collection_address: starknet::ContractAddress,
        approved: bool
    );
}


#[starknet::contract]
mod MarketPlace {
    use super::marketplace_structs::{Listing, Offer};
    use core::zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ListingCreated: ListingCreated,
        ListingUpdated: ListingUpdated,
        ListingCancelled: ListingCancelled,
        TokenSold: TokenSold,
        OfferCreated: OfferCreated,
        OfferAccepted: OfferAccepted,
        PlatformFeeChanged: PlatformFeeChanged,
        FeeRecipientChanged: FeeRecipientChanged,
        RoyaltySet: RoyaltySet,
        CollectionApprovalChanged: CollectionApprovalChanged
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCreated {
        listing_id: felt252,
        seller: ContractAddress,
        price: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingUpdated {
        listing_id: felt252,
        price: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCancelled {
        listing_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenSold {
        listing_id: felt252,
        buyer: ContractAddress,
        price: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct OfferCreated {
        listing_id: felt252,
        buyer: ContractAddress,
        offer_price: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct OfferAccepted {
        listing_id: felt252,
        buyer: ContractAddress,
        price: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct PlatformFeeChanged {
        new_fee: u16,
    }
    
    #[derive(Drop, starknet::Event)]
    struct FeeRecipientChanged {
        new_recipient: ContractAddress,
    }
    
    #[derive(Drop, starknet::Event)]
    struct RoyaltySet {
        token_id: felt252,
        recipient: ContractAddress,
        percentage: u16,
    }
    
    #[derive(Drop, starknet::Event)]
    struct CollectionApprovalChanged {
        collection: ContractAddress,
        approved: bool,
    }

    #[storage]
    struct Storage {
        listings: LegacyMap<felt252, Listing>,
        sold_tokens: LegacyMap<felt252, bool>,
        platform_fee_percentage: u16,
        platform_fee_recipient: ContractAddress,
        offers: LegacyMap<(felt252, ContractAddress), Offer>,
        collection_approval: LegacyMap<ContractAddress, bool>,
        listing_counter: felt252,
        token_royalties: LegacyMap<felt252, (ContractAddress, u16)>,
        admin: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        platform_fee_percentage: u16,
        platform_fee_recipient: ContractAddress,
        admin: ContractAddress
    ) {
        assert(platform_fee_percentage <= 1000, 'Fee must be <= 10%');
        assert(!platform_fee_recipient.is_zero(), 'Invalid fee recipient');
        assert(!admin.is_zero(), 'Invalid admin');
        
        self.platform_fee_percentage.write(platform_fee_percentage);
        self.platform_fee_recipient.write(platform_fee_recipient);
        self.admin.write(admin);
        self.listing_counter.write(1);
    }

    #[external(v0)]
    impl MarketPlaceImpl of super::IMarketPlace<ContractState> {
        fn get_listing(self: @ContractState, listing_id: felt252) -> Listing {
            self.listings.read(listing_id)
        }

        fn is_token_sold(self: @ContractState, token_id: felt252) -> bool {
            self.sold_tokens.read(token_id)
        }

        fn get_platform_fee(self: @ContractState) -> (u16, ContractAddress) {
            (
                self.platform_fee_percentage.read(),
                self.platform_fee_recipient.read()
            )
        }

        fn get_offer(
            self: @ContractState,
            listing_id: felt252,
            buyer: ContractAddress
        ) -> Offer {
            self.offers.read((listing_id, buyer))
        }

        fn get_token_royalty(self: @ContractState, token_id: felt252) -> (ContractAddress, u16) {
            self.token_royalties.read(token_id)
        }

        fn is_collection_approved(self: @ContractState, collection_address: ContractAddress) -> bool {
            self.collection_approval.read(collection_address)
        }
    
        fn list_nft(
            ref self: ContractState, 
            token_id: felt252, 
            price: felt252, 
            expiration: u64
        ) -> felt252 {
           
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Invalid caller');
            assert(price > 0, 'Price must be positive');
            
            
            let listing_id = self.listing_counter.read();
            self.listing_counter.write(listing_id + 1);
            
            
            let expiration_timestamp = if expiration == 0 {
                0
            } else {
                get_block_timestamp() + expiration
            };
            
            
            self.listings.write(
                listing_id, 
                Listing { 
                    token_id, 
                    price, 
                    seller: caller,
                    expiration: expiration_timestamp,
                    active: true
                }
            );
            
            
            self.emit(ListingCreated {
                listing_id,
                seller: caller,
                price
            });
            
           
            listing_id
        }

        fn update_listing(
            ref self: ContractState,
            listing_id: felt252,
            new_price: felt252,
            new_expiration: u64
        ) {
          
            let caller = get_caller_address();
            
           
            let mut listing = self.listings.read(listing_id);
            
           
            assert(listing.seller == caller, 'Not the seller');
            assert(listing.active, 'Listing not active');
            assert(new_price > 0, 'Price must be positive');
            
            
            listing.price = new_price;
            
           
            if new_expiration > 0 {
                listing.expiration = get_block_timestamp() + new_expiration;
            }
            
            
            self.listings.write(listing_id, listing);
            
          
            self.emit(ListingUpdated {
                listing_id,
                price: new_price
            });
        }

        fn cancel_listing(ref self: ContractState, listing_id: felt252) {
            
            let caller = get_caller_address();
            
           
            let mut listing = self.listings.read(listing_id);
            
          
            assert(listing.seller == caller, 'Not the seller');
            assert(listing.active, 'Listing not active');
            
            
            listing.active = false;
            self.listings.write(listing_id, listing);
            
           
            self.emit(ListingCancelled {
                listing_id
            });
        }

        fn purchase(ref self: ContractState, listing_id: felt252) {
            let caller = get_caller_address();
            let listing = self.listings.read(listing_id);
            
          
            assert(listing.active, 'Listing not active');
            if listing.expiration > 0 {
                assert(get_block_timestamp() <= listing.expiration, 'Listing expired');
            }
            
          
            self.sold_tokens.write(listing.token_id, true);
            
            
            let mut updated_listing = listing;
            updated_listing.active = false;
            self.listings.write(listing_id, updated_listing);
            
            
            self.emit(TokenSold {
                listing_id,
                buyer: caller,
                price: listing.price
            });
            
           
        }

        fn make_offer(
            ref self: ContractState,
            listing_id: felt252,
            offer_price: felt252,
            expiration: u64
        ) {
            let caller = get_caller_address();
            let listing = self.listings.read(listing_id);
            
            
            assert(listing.active, 'Listing not active');
            if listing.expiration > 0 {
                assert(get_block_timestamp() <= listing.expiration, 'Listing expired');
            }
            
            
            assert(offer_price > 0, 'Offer price must be positive');
            
            
            let expiration_timestamp = if expiration == 0 {
                0
            } else {
                get_block_timestamp() + expiration
            };
            
           
            self.offers.write(
                (listing_id, caller), 
                Offer {
                    listing_id,
                    buyer: caller,
                    offer_price,
                    expiration: expiration_timestamp
                }
            );
            
            
            self.emit(OfferCreated {
                listing_id,
                buyer: caller,
                offer_price
            });
        }

        fn accept_offer(
            ref self: ContractState,
            listing_id: felt252,
            buyer: ContractAddress
        ) {
            let caller = get_caller_address();
            let listing = self.listings.read(listing_id);
            let offer = self.offers.read((listing_id, buyer));
            
           
            assert(listing.seller == caller, 'Not the seller');
            assert(listing.active, 'Listing not active');
            
            
            assert(offer.buyer == buyer, 'Invalid buyer');
            assert(offer.offer_price > 0, 'Invalid offer');
            
            
            if offer.expiration > 0 {
                assert(get_block_timestamp() <= offer.expiration, 'Offer expired');
            }
            
            
            self.sold_tokens.write(listing.token_id, true);
            
            
            let mut updated_listing = listing;
            updated_listing.active = false;
            self.listings.write(listing_id, updated_listing);
          
            self.emit(OfferAccepted {
                listing_id,
                buyer,
                price: offer.offer_price
            });
            
            
        }

        fn set_platform_fee(
            ref self: ContractState,
            new_fee_percentage: u16
        ) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Not admin');
            assert(new_fee_percentage <= 1000, 'Fee must be <= 10%');
            
            self.platform_fee_percentage.write(new_fee_percentage);
            self.emit(PlatformFeeChanged { new_fee: new_fee_percentage });
        }

        fn set_platform_fee_recipient(
            ref self: ContractState,
            new_recipient: ContractAddress
        ) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Not admin');
            assert(!new_recipient.is_zero(), 'Invalid recipient');
            
            self.platform_fee_recipient.write(new_recipient);
            self.emit(FeeRecipientChanged { new_recipient });
        }

        fn set_token_royalty(
            ref self: ContractState,
            token_id: felt252,
            recipient: ContractAddress,
            royalty_percentage: u16
        ) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Not admin');
            assert(!recipient.is_zero(), 'Invalid recipient');
            assert(royalty_percentage <= 1000, 'Royalty must be <= 10%');
            
            self.token_royalties.write(token_id, (recipient, royalty_percentage));
            self.emit(RoyaltySet { 
                token_id,
                recipient,
                percentage: royalty_percentage
            });
        }

        fn approve_collection(
            ref self: ContractState,
            collection_address: ContractAddress,
            approved: bool
        ) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Not admin');
            assert(!collection_address.is_zero(), 'Invalid collection');
            
            self.collection_approval.write(collection_address, approved);
            self.emit(CollectionApprovalChanged {
                collection: collection_address,
                approved
            });
        }
    }
}