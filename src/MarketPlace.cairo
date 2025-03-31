#[starknet::contract]
mod MarketPlace {
    use core::zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::event::EventEmitter;

    #[derive(Drop, Serde, starknet::Event)]
    struct Listing {
        token_id: felt252,
        price: felt252,
        commitment: felt252,
        seller: ContractAddress,
        expiration: u64,
        active: bool,
    }

    #[derive(Drop, Serde, starknet::Event)]
    struct Offer {
        listing_id: felt252,
        buyer: ContractAddress,
        offer_price: felt252,
        expiration: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ListingCreated: ListingCreated,
        ListingUpdated: ListingUpdated,
        ListingCancelled: ListingCancelled,
        TokenSold: TokenSold,
        OfferCreated: OfferCreated,
        OfferAccepted: OfferAccepted,
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

    #[storage]
    struct Storage {
        listings: LegacyMap::<felt252, Listing>,
        sold_tokens: LegacyMap::<felt252, bool>,
        platform_fee_percentage: u16,
        platform_fee_recipient: ContractAddress,
        offers: LegacyMap::<(felt252, ContractAddress), Offer>,
        collection_approval: LegacyMap::<ContractAddress, bool>,
        listing_counter: felt252,
        token_royalties: LegacyMap::<felt252, (ContractAddress, u16)>,
        admin: ContractAddress,
    }

    #[view]
    fn get_admin(self: @ContractState) -> ContractAddress {
     self.admin.read()
    }
    #[constructor]
    fn constructor(
        ref self: ContractState,
        platform_fee_percentage: u16,
        platform_fee_recipient: ContractAddress
    ) {
        assert(platform_fee_percentage <= 1000, 'Fee must be <= 10%');
        assert(!platform_fee_recipient.is_zero(), 'Invalid fee recipient');
        
        self.platform_fee_percentage.write(platform_fee_percentage);
        self.platform_fee_recipient.write(platform_fee_recipient);
        self.listing_counter.write(1);
        self.admin.write(platform_fee_recipient);  
    }

    #[external(v0)]
    fn list_nft(
        ref self: ContractState, 
        token_id: felt252, 
        price: felt252, 
        expiration: u64,
        proof: Array<felt252>
    ) -> felt252 {
     
        let caller = get_caller_address();
        assert(!caller.is_zero(), 'Invalid caller');
        assert(price > 0, 'Price must be positive');
        
       
        
        let commitment = token_id;
        
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
                commitment,
                seller: caller,
                expiration: expiration_timestamp,
                active: true
            }
        );
    
        self.emit(Event::ListingCreated(ListingCreated {
            listing_id,
            seller: caller,
            price
        }));
       
        listing_id
    }

    #[external(v0)]
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
    
        self.emit(Event::ListingUpdated(ListingUpdated {
            listing_id,
            price: new_price
        }));
    }

    #[external(v0)]
    fn cancel_listing(ref self: ContractState, listing_id: felt252) {
 
        let caller = get_caller_address();
   
        let mut listing = self.listings.read(listing_id);
    
        assert(listing.seller == caller, 'Not the seller');
        assert(listing.active, 'Listing not active');
        
      
        listing.active = false;
        self.listings.write(listing_id, listing);
        
        
        self.emit(Event::ListingCancelled(ListingCancelled {
            listing_id
        }));
    }

    #[external(v0)]
    fn purchase(ref self: ContractState, listing_id: felt252, proof: Array<felt252>) {
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
        
    
        self.emit(Event::TokenSold(TokenSold {
            listing_id,
            buyer: caller,
            price: listing.price
        }));
    }

    #[external(v0)]
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
        
      
        self.emit(Event::OfferCreated(OfferCreated {
            listing_id,
            buyer: caller,
            offer_price
        }));
    }

    #[external(v0)]
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
        
        
        self.emit(Event::OfferAccepted(OfferAccepted {
            listing_id,
            buyer,
            price: offer.offer_price
        }));
        
        
    }

    #[external(v0)]
    fn set_platform_fee(
        ref self: ContractState,
        new_fee_percentage: u16
    ) {
       
        assert(new_fee_percentage <= 1000, 'Fee must be <= 10%');
        
        self.platform_fee_percentage.write(new_fee_percentage);
    }

    #[external(v0)]
    fn set_platform_fee_recipient(
        ref self: ContractState,
        new_recipient: ContractAddress
    ) {
       
        assert(!new_recipient.is_zero(), 'Invalid recipient');
        
        self.platform_fee_recipient.write(new_recipient);
    }

    #[external(v0)]
    fn set_token_royalty(
        ref self: ContractState,
        token_id: felt252,
        recipient: ContractAddress,
        royalty_percentage: u16
    ) {
       
        assert(!recipient.is_zero(), 'Invalid recipient');
        assert(royalty_percentage <= 1000, 'Royalty must be <= 10%');
        
        self.token_royalties.write(token_id, (recipient, royalty_percentage));
    }

    #[external(v0)]
    fn approve_collection(
        ref self: ContractState,
        collection_address: ContractAddress,
        approved: bool
    ) {
      
        assert(!collection_address.is_zero(), 'Invalid collection');
        
        self.collection_approval.write(collection_address, approved);
    }

    #[view]
    fn get_listing(self: @ContractState, listing_id: felt252) -> Listing {
        self.listings.read(listing_id)
    }

    #[view]
    fn is_token_sold(self: @ContractState, token_id: felt252) -> bool {
        self.sold_tokens.read(token_id)
    }

    #[view]
    fn get_platform_fee(self: @ContractState) -> (u16, ContractAddress) {
        (
            self.platform_fee_percentage.read(),
            self.platform_fee_recipient.read()
        )
    }

    #[view]
    fn get_offer(
        self: @ContractState,
        listing_id: felt252,
        buyer: ContractAddress
    ) -> Offer {
        self.offers.read((listing_id, buyer))
    }

    #[view]
    fn get_token_royalty(self: @ContractState, token_id: felt252) -> (ContractAddress, u16) {
        self.token_royalties.read(token_id)
    }

    #[view]
    fn is_collection_approved(self: @ContractState, collection_address: ContractAddress) -> bool {
        self.collection_approval.read(collection_address)
    }
}