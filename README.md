# UAH RWA

This project is implementation of the Stablecoin directly pegged to UAH. We gonna use two possible collaterals:

1. The real UAH stored on the MonoBank account
2. The limited set of the ERC20 tokens (stable-coins preferred) 

For receiving the amount of money stored on the MonoBank account and for receiving the actual rate of the UAH to corresponding ERC20 we are using Chainlink Functions.

## Deploy

1. Setup `deployer` account to the keystore:
 ```bash
 cast wallet import --interactive deployer
 ```

2. Create `.env` file in the root of the project, by example from `.env.example`. Be sure that `DEPLOYER_ADDRESS=` is equal to the `deployer` address (the wallet added at the step 1).

3. Run deployment command
 ```
 make deploy
 ```
