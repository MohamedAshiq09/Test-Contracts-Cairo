use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank};
use starknet::{ContractAddress, contract_address_const};
use private_marketplace::marketplace::IMarketPlaceDispatcher;
use private_marketplace::marketplace::IMarketPlaceDispatcherTrait;
use private_marketplace::anonymous_nft::IAnonymousNFTDispatcher;
use private_marketplace::anonymous_nft::IAnonymousNFTDispatcherTrait;
use array::ArrayTrait;

// Test Constants
const ADMIN_ADDRESS: felt252 = 0x123;
const SELLER_ADDRESS: felt252 = 0x456;
const BUYER_ADDRESS: felt252 = 0x789;
const PLATFORM_FEE_RECIPIENT: felt252 = 0xabc;
const TOKEN_ID: felt252 = 0x111;
const LISTING_PRICE: felt252 = 1000;
const OFFER_PRICE: felt252 = 900;

#[test]
fn test_marketplace_deployment() {
    // Deploy MarketPlace contract
    let marketplace_class = declare("MarketPlace");
    let platform_fee_recipient: ContractAddress = contract_address_const::<PLATFORM_FEE_RECIPIENT>();
    let platform_fee_percentage: u16 = 250; // 2.5%
    
    let mut calldata = ArrayTrait::new();
    calldata.append(platform_fee_percentage.into());
    calldata.append(platform_fee_recipient.into());
    let marketplace_address = marketplace_class.deploy(@calldata).unwrap();
    
    // Create dispatcher
    let marketplace_dispatcher = IMarketPlaceDispatcher { contract_address: marketplace_address };
    
    // Verify configuration
    let (fee, recipient) = marketplace_dispatcher.get_platform_fee();
    assert(fee == platform_fee_percentage, 'Fee not set correctly');
    assert(recipient == platform_fee_recipient, 'Recipient not set correctly');
}

#[test]
fn test_listing_and_updating() {
    // Deploy required contracts
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut verifier_calldata = ArrayTrait::new();
    verifier_calldata.append(admin.into());
    let verifier_address = verifier_class.deploy(@verifier_calldata).unwrap();
    
    let nft_class = declare("AnonymousNFT");
    let mut nft_calldata = ArrayTrait::new();
    nft_calldata.append(admin.into());
    nft_calldata.append(verifier_address.into());
    let nft_address = nft_class.deploy(@nft_calldata).unwrap();
    
    let marketplace_class = declare("MarketPlace");
    let platform_fee_recipient: ContractAddress = contract_address_const::<PLATFORM_FEE_RECIPIENT>();
    let platform_fee_percentage: u16 = 250; // 2.5%
    
    let mut marketplace_calldata = ArrayTrait::new();
    marketplace_calldata.append(platform_fee_percentage.into());
    marketplace_calldata.append(platform_fee_recipient.into());
    let marketplace_address = marketplace_class.deploy(@marketplace_calldata).unwrap();
    
    // Create dispatchers
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };
    let marketplace_dispatcher = IMarketPlaceDispatcher { contract_address: marketplace_address };
    
    // Mint an NFT
    let seller: ContractAddress = contract_address_const::<SELLER_ADDRESS>();
    start_prank(nft_address, seller);
    
    let mut mint_proof = ArrayTrait::new();
    mint_proof.append(0x1);
    nft_dispatcher.mint_anonymous(TOKEN_ID, mint_proof);
    
    stop_prank(nft_address);
    
    // Approve marketplace
    start_prank(marketplace_address, platform_fee_recipient);
    marketplace_dispatcher.approve_collection(nft_address, true);
    stop_prank(marketplace_address);
    
    // List NFT
    start_prank(marketplace_address, seller);
    
    let mut list_proof = ArrayTrait::new();
    list_proof.append(0x2);
    let expiration: u64 = 86400; // 1 day
    
    let listing_id = marketplace_dispatcher.list_nft(TOKEN_ID, LISTING_PRICE, expiration, list_proof);
    
    // Verify listing
    let listing = marketplace_dispatcher.get_listing(listing_id);
    assert(listing.token_id == TOKEN_ID, 'Incorrect token ID');
    assert(listing.price == LISTING_PRICE, 'Incorrect price');
    assert(listing.seller == seller, 'Incorrect seller');
    assert(listing.active, 'Listing should be active');
    
    // Update listing
    let new_price = LISTING_PRICE + 100;
    marketplace_dispatcher.update_listing(listing_id, new_price, expiration);
    
    // Verify updated listing
    let updated_listing = marketplace_dispatcher.get_listing(listing_id);
    assert(updated_listing.price == new_price, 'Price not updated');
    
    stop_prank(marketplace_address);
}

#[test]
fn test_offers_and_acceptance() {
    // Deploy required contracts
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut verifier_calldata = ArrayTrait::new();
    verifier_calldata.append(admin.into());
    let verifier_address = verifier_class.deploy(@verifier_calldata).unwrap();
    
    let nft_class = declare("AnonymousNFT");
    let mut nft_calldata = ArrayTrait::new();
    nft_calldata.append(admin.into());
    nft_calldata.append(verifier_address.into());
    let nft_address = nft_class.deploy(@nft_calldata).unwrap();
    
    let marketplace_class = declare("MarketPlace");
    let platform_fee_recipient: ContractAddress = contract_address_const::<PLATFORM_FEE_RECIPIENT>();
    let platform_fee_percentage: u16 = 250; // 2.5%
    
    let mut marketplace_calldata = ArrayTrait::new();
    marketplace_calldata.append(platform_fee_percentage.into());
    marketplace_calldata.append(platform_fee_recipient.into());
    let marketplace_address = marketplace_class.deploy(@marketplace_calldata).unwrap();
    
    // Create dispatchers
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };
    let marketplace_dispatcher = IMarketPlaceDispatcher { contract_address: marketplace_address };
    
    // Mint an NFT
    let seller: ContractAddress = contract_address_const::<SELLER_ADDRESS>();
    start_prank(nft_address, seller);
    
    let mut mint_proof = ArrayTrait::new();
    mint_proof.append(0x1);
    nft_dispatcher.mint_anonymous(TOKEN_ID, mint_proof);
    
    stop_prank(nft_address);
    
    // Approve marketplace
    start_prank(marketplace_address, platform_fee_recipient);
    marketplace_dispatcher.approve_collection(nft_address, true);
    stop_prank(marketplace_address);
    
    // List NFT
    start_prank(marketplace_address, seller);
    
    let mut list_proof = ArrayTrait::new();
    list_proof.append(0x2);
    let expiration: u64 = 86400; // 1 day
    
    let listing_id = marketplace_dispatcher.list_nft(TOKEN_ID, LISTING_PRICE, expiration, list_proof);
    
    stop_prank(marketplace_address);
    
    // Make an offer
    let buyer: ContractAddress = contract_address_const::<BUYER_ADDRESS>();
    start_prank(marketplace_address, buyer);
    
    marketplace_dispatcher.make_offer(listing_id, OFFER_PRICE, expiration);
    
    // Verify offer
    let offer = marketplace_dispatcher.get_offer(listing_id, buyer);
    assert(offer.buyer == buyer, 'Incorrect buyer');
    assert(offer.offer_price == OFFER_PRICE, 'Incorrect offer price');
    
    stop_prank(marketplace_address);
    
    // Accept offer
    start_prank(marketplace_address, seller);
    
    marketplace_dispatcher.accept_offer(listing_id, buyer);
    
    // Verify listing is inactive after acceptance
    let updated_listing = marketplace_dispatcher.get_listing(listing_id);
    assert(!updated_listing.active, 'Listing should be inactive');
    
    stop_prank(marketplace_address);
}

#[test]
fn test_direct_purchase() {
    // Deploy required contracts
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut verifier_calldata = ArrayTrait::new();
    verifier_calldata.append(admin.into());
    let verifier_address = verifier_class.deploy(@verifier_calldata).unwrap();
    
    let nft_class = declare("AnonymousNFT");
    let mut nft_calldata = ArrayTrait::new();
    nft_calldata.append(admin.into());
    nft_calldata.append(verifier_address.into());
    let nft_address = nft_class.deploy(@nft_calldata).unwrap();
    
    let marketplace_class = declare("MarketPlace");
    let platform_fee_recipient: ContractAddress = contract_address_const::<PLATFORM_FEE_RECIPIENT>();
    let platform_fee_percentage: u16 = 250; // 2.5%
    
    let mut marketplace_calldata = ArrayTrait::new();
    marketplace_calldata.append(platform_fee_percentage.into());
    marketplace_calldata.append(platform_fee_recipient.into());
    let marketplace_address = marketplace_class.deploy(@marketplace_calldata).unwrap();
    
    // Create dispatchers
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };
    let marketplace_dispatcher = IMarketPlaceDispatcher { contract_address: marketplace_address };
    
    // Mint an NFT
    let seller: ContractAddress = contract_address_const::<SELLER_ADDRESS>();
    start_prank(nft_address, seller);
    
    let mut mint_proof = ArrayTrait::new();
    mint_proof.append(0x1);
    nft_dispatcher.mint_anonymous(TOKEN_ID, mint_proof);
    
    stop_prank(nft_address);
    
    // Approve marketplace
    start_prank(marketplace_address, platform_fee_recipient);
    marketplace_dispatcher.approve_collection(nft_address, true);
    stop_prank(marketplace_address);
    
    // List NFT
    start_prank(marketplace_address, seller);
    
    let mut list_proof = ArrayTrait::new();
    list_proof.append(0x2);
    let expiration: u64 = 86400; // 1 day
    
    let listing_id = marketplace_dispatcher.list_nft(TOKEN_ID, LISTING_PRICE, expiration, list_proof);
    
    stop_prank(marketplace_address);
    
    // Direct purchase
    let buyer: ContractAddress = contract_address_const::<BUYER_ADDRESS>();
    start_prank(marketplace_address, buyer);
    
    let mut purchase_proof = ArrayTrait::new();
    purchase_proof.append(0x3);
    
    marketplace_dispatcher.purchase(listing_id, purchase_proof);
    
    // Verify listing is inactive after purchase
    let updated_listing = marketplace_dispatcher.get_listing(listing_id);
    assert(!updated_listing.active, 'Listing should be inactive');
    
    // Verify token is marked as sold
    assert(marketplace_dispatcher.is_token_sold(TOKEN_ID), 'Token should be marked as sold');
    
    stop_prank(marketplace_address);
}

#[test]
fn test_listing_cancellation() {
    // Deploy required contracts
    let verifier_class = declare("ZKVerifier");
    let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
    
    let mut verifier_calldata = ArrayTrait::new();
    verifier_calldata.append(admin.into());
    let verifier_address = verifier_class.deploy(@verifier_calldata).unwrap();
    
    let nft_class = declare("AnonymousNFT");
    let mut nft_calldata = ArrayTrait::new();
    nft_calldata.append(admin.into());
    nft_calldata.append(verifier_address.into());
    let nft_address = nft_class.deploy(@nft_calldata).unwrap();
    
    let marketplace_class = declare("MarketPlace");
    let platform_fee_recipient: ContractAddress = contract_address_const::<PLATFORM_FEE_RECIPIENT>();
    let platform_fee_percentage: u16 = 250; // 2.5%
    
    let mut marketplace_calldata = ArrayTrait::new();
    marketplace_calldata.append(platform_fee_percentage.into());
    marketplace_calldata.append(platform_fee_recipient.into());
    let marketplace_address = marketplace_class.deploy(@marketplace_calldata).unwrap();
    
    // Create dispatchers
    let nft_dispatcher = IAnonymousNFTDispatcher { contract_address: nft_address };
    let marketplace