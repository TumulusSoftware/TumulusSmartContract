# TumulusSmartContract
This repo is meant to hold a collection of smart contracts for various blockchain networks. 

Currently the only existing contract is written in Solidity and ready to be deployed to an Ethereum-based network.

Tumulus Smart Contracts provide data access permission marshalling based on states of data owners.

# DataSitter.sol

This smart contract is written in Solidity and must be deployed to an Ethereum-based network.

## Prerequisites

For information and guidance on getting started developing smart contracts in Solidity go here: ```https://ethereum.org/en/developers/docs/smart-contracts/```

## I want to deploy the Tumulus Smart Contract

1. Clone the repo

```https://github.com/TumulusSoftware/TumulusSmartContract.git```

2. Compile the contract

For information and guidance on compiling smart contracts go here: https://ethereum.org/en/developers/docs/smart-contracts/compiling/

3. Deploy the contract

For information and guidance on deploying smart contracts go here: https://ethereum.org/en/developers/docs/smart-contracts/deploying/

## How it Works

The DataSitter contract is designed to track specific states of data owners. A data owner is an individual or party who owns the data that is stored via the Tumulus API. The smart contract is able to track the owner state and grant certain access permissions to other individuals or parties based on changes in owner state.

## Using the Smart Contract

Smart contracts deployed to the blockchain are given their own unique address and as such, in order to use the smart contract you must deploy your own version of DataSitter to the blockchain. Follow the links above for guidance on deploying smart contracts.

__Note:__ _Deploying a Smart Contract involves blockchain activity and will incur GAS fees._

## Owner States

Owner states are stored as a single integer where each bit represents ```agrm``` unique state.

The Tumulus Smart Contract supports a minimum of 8 bits and a maximum of 256 bits for the MAX_USER_STATE value. The default configured value is 8 however this can be set to a multiple of 8 up to 256 before deploying the smart contract.

## Data Structs

### User

A data object to hold the current state of an Owner.

### State

A data object to hold configuration options for each given state.

### Asset

A data object to hold the relationship between an owner and a data asset stored on IPFS. The IPFS CID is encrypted and stored as a property of this object.

### Authorization

A data object to hold the relationship between an owner, a viewer and the protected data asset. Viewers are individuals who have been granted access permissions to an owner's asset based on a given state of the owner.

### Agreement

A data object to hold the relationship between an owner and an announcer. An annoucer is an individual who has agreed to verify and validate a change in the state of the owner.

## Contributing

Contributions are welcome. Please see the [Contributing Guidelines](CONTRIBUTING.md) guide to see how you can get involved.

## Code of Conduct

This project is governed by the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are
expected to uphold this code of conduct. Please report unacceptable behavior to [abuse@tumulus.io](mailto:abuse@tumulus.io)

## License

[Apache License 2.0](LICENSE)