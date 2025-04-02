#[cfg(test)]
mod tests {
    use super::MarketPlace;
    use super::MarketPlace::IMarketPlaceDispatcher;
    use super::MarketPlace::IMarketPlaceDispatcherTrait;
    use starknet::{ContractAddress, contract_address_const};
    use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait };

    fn deploy_marketplace(platform_fee_percentage: u16, platform_fee_recipient: ContractAddress) -> (IMarketPlaceDispatcher, ContractAddress) {
        let contract = declare("MarketPlace");
        let mut constructor_calldata = array![platform_fee_percentage.into(), platform_fee_recipient.into()];
        
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_calldata)
            .unwrap();

        let dispatcher = IMarketPlaceDispatcher { contract_address };
        (dispatcher, contract_address)
    }

    #[test]
    fn test_list_nft() {
        let platform_fee_percentage: u16 = 100;
        let platform_fee_recipient: ContractAddress = contract_address_const::<'recipient'>();
        let (marketplace_dispatcher, marketplace_address) = deploy_marketplace(platform_fee_percentage, platform_fee_recipient);

        let token_id: felt252 = 123;
        let price: felt252 = 1000;
        let expiration: u64 = 100;
        let proof: Array<felt252> = array![1, 2, 3];

        start_cheat_caller_address(marketplace_address, platform_fee_recipient);
        let listing_id = marketplace_dispatcher.list_nft(token_id, price, expiration, proof);
        stop_cheat_caller_address(marketplace_address);

        let listing = marketplace_dispatcher.get_listing(listing_id);
        assert(listing.price == price, 'Price should match');
    }

    #[test]
    fn test_purchase() {
        let platform_fee_percentage: u16 = 100;
        let platform_fee_recipient: ContractAddress = contract_address_const::<'recipient'>();
        let (marketplace_dispatcher, marketplace_address) = deploy_marketplace(platform_fee_percentage, platform_fee_recipient);

        let token_id: felt252 = 123;
        let price: felt252 = 1000;
        let expiration: u64 = 100;
        let proof: Array<felt252> = array![1, 2, 3];

        start_cheat_caller_address(marketplace_address, platform_fee_recipient);
        let listing_id = marketplace_dispatcher.list_nft(token_id, price, expiration, proof);
        stop_cheat_caller_address(marketplace_address);

        let purchase_proof: Array<felt252> = array![4,5,6];
        start_cheat_caller_address(marketplace_address, platform_fee_recipient);
        marketplace_dispatcher.purchase(listing_id, purchase_proof);
        stop_cheat_caller_address(marketplace_address);

        assert(marketplace_dispatcher.is_token_sold(token_id), 'Token should be sold');
    }
}