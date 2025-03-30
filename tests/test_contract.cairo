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


use anonymous_nft::AnonymousNFT;
use marketplace::MarketPlace;

#[test]
fn test_nft_mint_and_purchase() {
    // Deploy contracts
    let nft = AnonymousNFT::deploy(@array![]).unwrap();
    let market = MarketPlace::deploy(@array![]).unwrap();

    // Mint NFT (simplified)
    nft.mint_anonymous(123, @array![]);
    let owner = nft.get_owner(123);
    println!("Owner: {}", owner);

    // List NFT
    market.list_nft(1, 123, 100, @array![]);
    
    // Purchase
    market.purchase(1, @array![]);
    assert(market.sold_tokens.read(123) == true, "NFT not sold");
}