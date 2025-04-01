#[starknet::contract]
mod AnonymousNFT {
    use core::zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::event::EventEmitter;
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CommitmentRegistered: CommitmentRegistered,
        CommitmentTransferred: CommitmentTransferred,
        CommitmentBurned: CommitmentBurned
    }

    #[derive(Drop, starknet::Event)]
    struct CommitmentRegistered {
        commitment: felt252,
        owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct CommitmentTransferred {
        commitment: felt252,
        new_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct CommitmentBurned {
        commitment: felt252
    }

    #[storage]
    struct Storage {
        commitment_owner: LegacyMap::<felt252, ContractAddress>,
        commitment_exists: LegacyMap::<felt252, bool>,
        owner_commitment_count: LegacyMap::<ContractAddress, u256>,
        total_supply: u256,
        admin: ContractAddress,
        zk_verifier: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        admin_address: ContractAddress,
        verifier_address: ContractAddress
    ) {
        self.admin.write(admin_address);
        self.zk_verifier.write(verifier_address);
        self.total_supply.write(0);
    }
    
    // ZK Verifier Interface
    #[starknet::interface]
    trait IZKVerifier<T> {
        fn verify_proof(self: @T, proof: Array<felt252>) -> felt252;
        fn verify_ownership(self: @T, commitment: felt252, proof: Array<felt252>) -> felt252;
    }

    // Generate ZK Verifier Dispatcher
    #[starknet::interface]
     trait IZKVerifierDispatcherTrait<T> {
       fn verify_proof(self: @T, proof: Array<felt252>) -> felt252;
       fn verify_ownership(self: @T, commitment: felt252, proof: Array<felt252>) -> felt252;
    }

    #[external(v0)]
    fn mint_anonymous(ref self: ContractState, commitment: felt252, proof: Array<felt252>) {
        // Call the ZK Verifier to validate the proof
        let verifier_address = self.zk_verifier.read();
        let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
        let is_valid = verifier_dispatcher.verify_proof(proof);
        
        assert(is_valid == 1, "Invalid proof");
        assert(!self.commitment_exists.read(commitment), "Commitment already registered");
        
        let caller = get_caller_address();
         
        self.commitment_owner.write(commitment, caller);
        self.commitment_exists.write(commitment, true);
         
        let current_count = self.owner_commitment_count.read(caller);
        self.owner_commitment_count.write(caller, current_count + 1);
        
        let current_supply = self.total_supply.read();
        self.total_supply.write(current_supply + 1);
       
        self.emit(CommitmentRegistered { commitment, owner: caller });
    }
    
    #[external(v0)]
    fn mint_anonymous(ref self: ContractState, commitment: felt252, proof: Array<felt252>) {
        // Call the ZK Verifier to validate the proof
        let verifier_address = self.zk_verifier.read();
        let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
        let is_valid = verifier_dispatcher.verify_proof(proof);
        
        assert(is_valid == 1, "Invalid proof");
        assert(!self.commitment_exists.read(commitment), "Commitment already registered");
        
        let caller = get_caller_address();
         
        self.commitment_owner.write(commitment, caller);
        self.commitment_exists.write(commitment, true);
         
        let current_count = self.owner_commitment_count.read(caller);
        self.owner_commitment_count.write(caller, current_count + 1);
        
        let current_supply = self.total_supply.read();
        self.total_supply.write(current_supply + 1);
       
        self.emit(CommitmentRegistered { commitment, owner: caller });
    }
    
    #[external(v0)]
    fn transfer_anonymous(
        ref self: ContractState, 
        commitment: felt252, 
        new_owner: ContractAddress,
        ownership_proof: Array<felt252>
    ) {
        // Call the ZK Verifier to validate ownership proof
        let verifier_address = self.zk_verifier.read();
        let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
        let is_valid = verifier_dispatcher.verify_ownership(commitment, ownership_proof);
        
        assert(is_valid == 1, "Invalid ownership proof");
        
        let caller = get_caller_address();
        let current_owner = self.commitment_owner.read(commitment);
        
        assert(current_owner == caller, "Not the commitment owner");
        assert(self.commitment_exists.read(commitment), "Commitment does not exist");
        
        self.commitment_owner.write(commitment, new_owner);
    
        let current_owner_count = self.owner_commitment_count.read(caller);
        self.owner_commitment_count.write(caller, current_owner_count - 1);
        
        let new_owner_count = self.owner_commitment_count.read(new_owner);
        self.owner_commitment_count.write(new_owner, new_owner_count + 1);
        
        self.emit(CommitmentTransferred { commitment, new_owner });
    }
    
    #[external(v0)]
    fn burn_anonymous(ref self: ContractState, commitment: felt252, ownership_proof: Array<felt252>) {
        // Call the ZK Verifier to validate ownership proof
        let verifier_address = self.zk_verifier.read();
        let verifier_dispatcher = IZKVerifierDispatcher { contract_address: verifier_address };
        let is_valid = verifier_dispatcher.verify_ownership(commitment, ownership_proof);
        
        assert(is_valid == 1, "Invalid ownership proof");
        
        let caller = get_caller_address();
        let current_owner = self.commitment_owner.read(commitment);
        
        assert(current_owner == caller, "Not the commitment owner");
        assert(self.commitment_exists.read(commitment), "Commitment does not exist");
        
        self.commitment_owner.write(commitment, Zeroable::zero());
        self.commitment_exists.write(commitment, false);
        
        let current_count = self.owner_commitment_count.read(caller);
        self.owner_commitment_count.write(caller, current_count - 1);
        
        let current_supply = self.total_supply.read();
        self.total_supply.write(current_supply - 1);
    
        self.emit(CommitmentBurned { commitment });
    }
    
    #[view(v0)]
    fn get_owner(self: @ContractState, commitment: felt252) -> ContractAddress {
        self.commitment_owner.read(commitment)
    }
    
    #[view(v0)]
    fn commitment_exists(self: @ContractState, commitment: felt252) -> bool {
        self.commitment_exists.read(commitment)
    }
    
    #[view(v0)]
    fn get_owner_commitment_count(self: @ContractState, owner: ContractAddress) -> u256 {
        self.owner_commitment_count.read(owner)
    }
    
    #[view(v0)]
    fn get_total_supply(self: @ContractState) -> u256 {
        self.total_supply.read()
    }
    
    #[view(v0)]
    fn get_admin(self: @ContractState) -> ContractAddress {
        self.admin.read()
    }
    
    #[view(v0)]
    fn get_verifier(self: @ContractState) -> ContractAddress {
        self.zk_verifier.read()
    }
    
    #[external(v0)]
    fn set_admin(ref self: ContractState, new_admin: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), "Only admin can change admin");
        self.admin.write(new_admin);
    }
    
    #[external(v0)]
    fn set_verifier(ref self: ContractState, new_verifier: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), "Only admin can change verifier");
        self.zk_verifier.write(new_verifier);
    }
}