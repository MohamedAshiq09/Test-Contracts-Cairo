#[starknet::contract]
mod MarketPlace {
    use core::zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address};

    #[derive(Drop, Serde)]
    struct Listing {
        token_id: felt252,
        price: felt252,
        commitment: felt252,
    }

    #[storage]
    struct Storage {
        listings: LegacyMap::<felt252, Listing>,
        sold_tokens: LegacyMap::<felt252, bool>,
    }

    #[external(v0)]
    fn list_nft(
        ref self: ContractState, 
        listing_id: felt252, 
        token_id: felt252, 
        price: felt252, 
        proof: Array<felt252>
    ) {
        // In a real implementation, you would verify ZK proof here
        // let commitment = AnonymousNFT::get_commitment(token_id);
        
        let commitment = token_id; // Simplified for this example
        self.listings.write(
            listing_id, 
            Listing { token_id, price, commitment }
        );
    }

    #[external(v0)]
    fn purchase(ref self: ContractState, listing_id: felt252, proof: Array<felt252>) {
        let listing = self.listings.read(listing_id);
        
        // In a real implementation, you would verify ZK proof here
        
        self.sold_tokens.write(listing.token_id, true);
    }
}
EOF

# Create a main file to export your contracts
cat > src/lib.cairo << 'EOF'
mod anonymous_nft;
mod marketplace;