# YieldStack

## A Secure DeFi Yield Farming Protocol on Stacks Blockchain

YieldStack is a decentralized finance (DeFi) protocol built on the Stacks blockchain that enables strategic yield farming with sequential vault progression and proof-of-stake verification.

## Overview

YieldStack optimizes yield farming by implementing a sequential vault system with time-locked rewards. Farmers progress through a series of vaults, each requiring proof-of-stake verification to harvest yields. This approach ensures fair distribution and incentivizes long-term participation.

## Key Features

- **Sequential Vault Progression**: Farmers advance through vaults in order, creating a gamified yield farming experience
- **Proof-of-Stake Verification**: Secure harvesting with cryptographic verification
- **Time-Locked Rewards**: Vaults unlock at specific block heights to encourage long-term commitment
- **Transparent Tracking**: Comprehensive event logging for all harvest activities
- **Scalable Architecture**: Support for up to 100 distinct yield vaults

## Architecture

YieldStack consists of the following core components:

### Data Structures

- **Yield Vaults**: Stores strategy information, verification requirements, and reward amounts
- **Farmer Positions**: Tracks user progress through the protocol
- **Harvest Events**: Records all successful yield harvests for transparency

### Protocol Flow

1. **Admin Setup**: Protocol admin creates vaults with specific strategies and unlock conditions
2. **Farmer Onboarding**: Users deposit an entry fee to join the protocol
3. **Vault Progression**: Farmers harvest yields by providing valid proof-of-stake
4. **Reward Distribution**: STX tokens are transferred to farmers upon successful harvests

## Smart Contract Functions

### Admin Functions

- `launch-pool`: Activate the protocol for farmer participation
- `create-vault`: Define a new yield vault with specific parameters
- `update-block`: Update the current block height (for testing purposes)

### Farmer Functions

- `deposit-liquidity`: Join the protocol by depositing the required entry fee
- `harvest-yield`: Claim rewards from a vault by providing valid proof-of-stake

### Read-Only Functions

- `get-vault-strategy`: Retrieve the strategy for a specific vault
- `get-farmer-status`: Check a farmer's current position and harvest history
- `get-harvest-events`: View all harvest events for a specific vault
- `get-current-block`: Get the current block height
- `get-pool-stats`: Retrieve overall protocol statistics

