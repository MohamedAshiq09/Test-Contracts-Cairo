use starknet::ClassHash;

trait TestClassHashTrait {
    fn TEST_CLASS_HASH() -> ClassHash;
}

// Implement the trait for each contract
impl AnonymousNFTImpl of TestClassHashTrait {
    fn TEST_CLASS_HASH() -> ClassHash {
        ClassHash { value: 'AnonymousNFT' }
    }
}

impl MarketPlaceImpl of TestClassHashTrait {
    fn TEST_CLASS_HASH() -> ClassHash {
        ClassHash { value: 'MarketPlace' }
    }
}

impl ZKVerifierImpl of TestClassHashTrait {
    fn TEST_CLASS_HASH() -> ClassHash {
        ClassHash { value: 'ZKVerifier' }
    }
}