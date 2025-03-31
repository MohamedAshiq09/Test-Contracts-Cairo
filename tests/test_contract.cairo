// use starknet::ContractAddress;

// use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

// use contract::IHelloStarknetSafeDispatcher;
// use contract::IHelloStarknetSafeDispatcherTrait;
// use contract::IHelloStarknetDispatcher;
// use contract::IHelloStarknetDispatcherTrait;

// fn deploy_contract(name: ByteArray) -> ContractAddress {
//     let contract = declare(name).unwrap().contract_class();
//     let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
//     contract_address
// }

// #[test]
// fn test_increase_balance() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let dispatcher = IHelloStarknetDispatcher { contract_address };

//     let balance_before = dispatcher.get_balance();
//     assert(balance_before == 0, 'Invalid balance');

//     dispatcher.increase_balance(42);

//     let balance_after = dispatcher.get_balance();
//     assert(balance_after == 42, 'Invalid balance');
// }

// #[test]
// #[feature("safe_dispatcher")]
// fn test_cannot_increase_balance_with_zero_value() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let balance_before = safe_dispatcher.get_balance().unwrap();
//     assert(balance_before == 0, 'Invalid balance');

//     match safe_dispatcher.increase_balance(0) {
//         Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
//         Result::Err(panic_data) => {
//             assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
//         }
//     };
// }

use starknet::{ContractAddress, contract_address_const};
use starknet::testing::set_caller_address;
use debug::PrintTrait;


use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};


use contract::lib::anonymous_nft::{IAnonymousNFTDispatcher, IAnonymousNFTDispatcherTrait};
use contract::lib::marketplace::{IMarketPlaceDispatcher, IMarketPlaceDispatcherTrait};


fn deploy_anonymous_nft() -> IAnonymousNFTDispatcher {
 
    let contract = declare("AnonymousNFT");
    let admin_address = contract_address_const::<0x123>();
    let constructor_calldata = array![admin_address.into()];
   
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    
   
    IAnonymousNFTDispatcher { contract_address }
}


fn deploy_marketplace() -> IMarketPlaceDispatcher {
  
    let contract = declare("MarketPlace");
    let fee_percentage: u16 = 250; // 2.5%
    let fee_recipient = contract_address_const::<0x456>();
    
    let constructor_calldata = array![fee_percentage.into(), fee_recipient.into()];
    let contract_address = contract.deploy(@constructor_calldata).unwrap();
    

    IMarketPlaceDispatcher { contract_address }
}

#[test]
fn test_anonymous_nft_mint() {
    
    let nft_dispatcher = deploy_anonymous_nft();
    
    let user = contract_address_const::<0x567>();
    start_prank(CheatTarget::One(nft_dispatcher.contract_address), user);
   
    let commitment: felt252 = 123;
    let proof: Array<felt252> = array![];
    nft_dispatcher.mint_anonymous(commitment, proof);
   
    let owner = nft_dispatcher.get_owner(commitment);
    assert(owner == user, 'Owner should be the user');
    
    assert(nft_dispatcher.commitment_exists(commitment), 'Commitment should exist');
    
    assert(nft_dispatcher.get_total_supply() == 1_u256, 'Total supply should be 1');
    assert(nft_dispatcher.get_owner_commitment_count(user) == 1_u256, 'User should own 1 NFT');
    
    stop_prank(CheatTarget::One(nft_dispatcher.contract_address));
}

#[test]
fn test_marketplace_listing_and_purchase() {
  
    let nft_dispatcher = deploy_anonymous_nft();
    let market_dispatcher = deploy_marketplace();
    
   
    let seller = contract_address_const::<0x567>();
    let buyer = contract_address_const::<0x789>();
   
    start_prank(CheatTarget::One(nft_dispatcher.contract_address), seller);
    let commitment: felt252 = 456;
    let proof: Array<felt252> = array![];
    nft_dispatcher.mint_anonymous(commitment, proof);
    stop_prank(CheatTarget::One(nft_dispatcher.contract_address));
    
    start_prank(CheatTarget::One(market_dispatcher.contract_address), seller);
    let price: felt252 = 1000; 
    let expiration: u64 = 86400; 
    let listing_id = market_dispatcher.list_nft(commitment, price, expiration, proof);
  
    let listing = market_dispatcher.get_listing(listing_id);
    assert(listing.token_id == commitment, 'Wrong token_id');
    assert(listing.price == price, 'Wrong price');
    assert(listing.seller == seller, 'Wrong seller');
    assert(listing.active, 'Listing should be active');
    stop_prank(CheatTarget::One(market_dispatcher.contract_address));
    
    start_prank(CheatTarget::One(market_dispatcher.contract_address), buyer);
    market_dispatcher.purchase(listing_id, proof);
    
    assert(market_dispatcher.is_token_sold(commitment), 'Token should be marked as sold');
    
    let updated_listing = market_dispatcher.get_listing(listing_id);
    assert(!updated_listing.active, 'Listing should not be active');
    stop_prank(CheatTarget::One(market_dispatcher.contract_address));
}

#[test]
fn test_offer_and_acceptance() {

    let nft_dispatcher = deploy_anonymous_nft();
    let market_dispatcher = deploy_marketplace();
   
    let seller = contract_address_const::<0x567>();
    let buyer = contract_address_const::<0x789>();
   
    start_prank(CheatTarget::One(nft_dispatcher.contract_address), seller);
    let commitment: felt252 = 789;
    let proof: Array<felt252> = array![];
    nft_dispatcher.mint_anonymous(commitment, proof);
    stop_prank(CheatTarget::One(nft_dispatcher.contract_address));
    
    start_prank(CheatTarget::One(market_dispatcher.contract_address), seller);
    let price: felt252 = 1000; 
    let expiration: u64 = 86400; 
    let listing_id = market_dispatcher.list_nft(commitment, price, expiration, proof);
    stop_prank(CheatTarget::One(market_dispatcher.contract_address));
   
    start_prank(CheatTarget::One(market_dispatcher.contract_address), buyer);
    let offer_price: felt252 = 800; 
    let offer_expiration: u64 = 43200; 
    market_dispatcher.make_offer(listing_id, offer_price, offer_expiration);
    stop_prank(CheatTarget::One(market_dispatcher.contract_address));

    let offer = market_dispatcher.get_offer(listing_id, buyer);
    assert(offer.listing_id == listing_id, 'Wrong listing_id');
    assert(offer.buyer == buyer, 'Wrong buyer');
    assert(offer.offer_price == offer_price, 'Wrong offer price');
  
    start_prank(CheatTarget::One(market_dispatcher.contract_address), seller);
    market_dispatcher.accept_offer(listing_id, buyer);
    stop_prank(CheatTarget::One(market_dispatcher.contract_address));
    
    assert(market_dispatcher.is_token_sold(commitment), 'Token should be marked as sold');
    
    let updated_listing = market_dispatcher.get_listing(listing_id);
    assert(!updated_listing.active, 'Listing should not be active');
}