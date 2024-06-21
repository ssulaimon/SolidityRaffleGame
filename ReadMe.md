# RaffleGame Smart Contract

## Overview

RaffleGame is a smart contract for a decentralized raffle game built on the Ethereum blockchain. This contract allows users to enter a raffle by paying an entry fee, and periodically selects a random winner using Chainlink's VRF (Verifiable Random Function) to ensure fairness. The winner receives the accumulated balance of the contract, and participants earn reward tokens.

## Features

- **Random Winner Selection**: Uses Chainlink VRF for secure and verifiable random number generation.
- **Automated Upkeep**: Uses Chainlink Automation to manage the raffle state and perform upkeep tasks.
- **Reward Tokens**: Participants earn reward tokens when entering the raffle.
- **Owner Controls**: The contract owner can manage various parameters such as entry fees, game state, and intervals.

## Table of Contents

- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Usage](#usage)
- [Contract Functions](#contract-functions)
- [Custom Errors](#custom-errors)
- [License](#license)

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/)
- [Truffle](https://www.trufflesuite.com/truffle)
- [Chainlink](https://docs.chain.link/docs)

### Installation

Clone the repository and install the dependencies:

```bash
git clone https://github.com/yourusername/rafflegame.git
cd rafflegame
npm install
```

## Deployment

To deploy the contract, configure your deployment script with the appropriate parameters and run:

```bash
truffle migrate --network yourNetwork
```

## Usage

### Entering the Raffle

To enter the raffle, users need to send a transaction with the appropriate entry fee. The contract checks the entry fee, ensures the user has not already entered, and that the raffle is open.

```javascript
await raffleGame.enterRaffleGame({ value: web3.utils.toWei('0.1', 'ether') });
```

### Claiming Reward Tokens

Users can claim their earned reward tokens by calling the `claimRewardToken` function with the amount they wish to claim.

```javascript
await raffleGame.claimRewardToken(amount);
```

## Contract Functions

### Constructor

```solidity
constructor(
    uint256 _entryFee,
    address _aggregatorV3InterfaceAddress,
    address _vrfCoordinatorV2PlusAddress,
    bytes32 _keyHash,
    uint256 _subId
) VRFConsumerBaseV2Plus(_vrfCoordinatorV2PlusAddress)
```

### Modifiers

- `isOwner()`: Ensures the caller is the contract owner.
- `feeAndDoubleEntryGameStateChecker()`: Checks if the entry fee is sufficient, the user has not already entered, and the raffle is open.

### Main Functions

- `enterRaffleGame()`: Allows users to enter the raffle.
- `checkUpkeep()`: Chainlink function to check if upkeep is needed.
- `performUpkeep()`: Chainlink function to perform upkeep tasks.
- `fulfillRandomWords()`: Callback function for Chainlink VRF to handle the random number and select a winner.
- `claimRewardToken(uint256 _amount)`: Allows users to claim their earned reward tokens.

### Setter Functions

- `setRewardTokenDetails(address _rewardTokenAddress)`: Sets the reward token contract address.
- `setNewEntryFee(uint256 _newEntryFee)`: Updates the entry fee.
- `setGameState(RaffleGameState _newRaffleGameState)`: Updates the game state.
- `setNewInterval(uint256 _newInterval)`: Updates the interval between raffles.

### Getter Functions

- `getBaseAssetEntryFee()`: Returns the converted entry fee in base asset.
- `getUSEntryFee()`: Returns the entry fee in USD.
- `getOwnerAddress()`: Returns the owner's address.
- `getAddressAlreadyEntered(address _address)`: Checks if an address has already entered.
- `getPlayers()`: Returns the list of players.
- `getRaffleGameState()`: Returns the current game state.
- `getInterval()`: Returns the interval between raffles.
- `getRequestId()`: Returns the current request ID.
- `getRewardTokenBalance()`: Returns the remaining reward token supply.
- `getEarnedTokenAmount(address _address)`: Returns the earned token amount for an address.
- `getLatestWinner()`: Returns the latest winner.
- `getRewardTokenAddress()`: Returns the reward token contract address.
- `getRewardTokenContractBalance()`: Returns the reward token balance of the contract.

## Custom Errors

- `RaffleGame__NotOwner(address caller)`
- `RaffGame_NotEnoughEntryAmount(uint256 amount)`
- `RaffleGame__AlreadyEnteredRaffle(address player)`
- `RaffleGame__RaffleIsNotOpen()`
- `RaffleGame__NotEnoughPlayer()`
- `RaffleGame__NotYetTime()`
- `RaffleGame__NotEnoughContractBalance()`
- `RaffleGame__UpKeepIsNotNeeded(uint256 playersLength, uint256 balance, RaffleGameState gameState, uint256 interval)`
- `RaffleGame__InvalidRequestId(uint256 requestId)`
- `RaffleGame__InsufficientRewardEarned()`
- `RaffleGame__TransactionFailed()`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.