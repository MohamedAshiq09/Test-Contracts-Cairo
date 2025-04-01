# Anonymous NFT Marketplace on StarkNet

An anonymous NFT marketplace built on StarkNet enabling completely private NFT trading, leveraging zero-knowledge proofs for identity verification and anonymity.

## Key Features

- **Zero-knowledge proof identity verification**: Users can prove ownership without revealing identity
- **Private transactions**: No public link between buyers and sellers
- **Anonymous bidding and sales**: Make and accept offers without exposing identity
- **No link between real-world identity and wallet activity**: Complete privacy for NFT trading

## Project Structure

```
anonymous-nft-marketplace/
├── src/
│   ├── AnonymousNFT.cairo        # NFT contract with anonymous operations
│   ├── MarketPlace.cairo         # Marketplace for anonymous listings/sales
│   ├── ZKVerifier.cairo          # Zero-knowledge proof verification
│   └── lib.cairo                 # Contract interfaces
├── tests/
│   └── test_contract.cairo       # Tests for contracts
├── scripts/
│   └── deploy.cairo              # Deployment scripts
├── Scarb.toml                    # Project configuration
├── Scarb.lock                    # Dependencies lock file
├── snfoundry.toml                # Foundry configuration
└── .gitignore                    # Git ignore file
```

## Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [StarkNet Foundry](https://foundry-rs.github.io/starknet-foundry/) (Contract development toolkit)
- [StarkNet CLI](https://www.starknetjs.com/docs/API/cli) (Command-line interface for StarkNet)

## Setup & Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/anonymous-nft-marketplace.git
cd anonymous-nft-marketplace
```

2. Install dependencies:

```bash
scarb update
```

## Building the Project

```bash
scarb build
```

## Running Tests

```bash
scarb test
```

## Deployment

### Preparation

1. Have StarkNet wallet with funds (ETH for transaction fees)
2. Declare contract class hashes using StarkNet CLI
3. Update the deploy.cairo script with your class hashes

### Declare Contracts

```bash
starknet declare --contract target/dev/contract_ZKVerifier.sierra.json --account your_account --network testnet
starknet declare --contract target/dev/contract_AnonymousNFT.sierra.json --account your_account --network testnet
starknet declare --contract target/dev/contract_MarketPlace.sierra.json --account your_account --network testnet
```

### Deploy Using Script

1. Update the class hashes in `scripts/deploy.cairo`
2. Run the deployment script:

```bash
scarb run deploy --private-key YOUR_PRIVATE_KEY
```

## Interacting with the Contracts

```bash
# Mint an anonymous NFT
starknet invoke --address NFT_CONTRACT_ADDRESS --function mint_anonymous --inputs COMMITMENT PROOF --account YOUR_ACCOUNT

# List