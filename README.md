# Provably Random Raffle Contract

## About

This code creates a provably random smart contract lottery.

## We want to achieve the following -

1. Users can enter the lottery by paying entrance fees.
    - The tickets fees will go to the winner during the draw.
2. After X period of time, the lottery will automatically draw a winner.
    - This will be done programmatically
3. We will use Chainlink VRF & Chainlink Automation.
    - Chainlink VRF -> Randomness
    - Chainlink Automation -> Time based trigger


## Tests

1. Write the deploy script
2. Write the tests
    - Work on a local chain
    - Work on forked testnet
    - Work on mainnet