-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil deploy-anvil

all: remove build test

# Clean the repo
clean :; forge clean

# Remove modules
remove :; rm -rf ../.gitmodules && rm -rf ../.git/modules/* && rm -rf lib && touch ../.gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

format :; forge fmt

coverage :; forge coverage --ir-minimum

coverage-report :; forge coverage --ir-minimum --report debug > coverage-report.txt

slither :; slither . --config-file slither.config.json

deploy :; forge script script/Deploy.s.sol \
	--account deployer \
	--rpc-url ${RPC_URL} \
	--legacy \
	--verify \
	--etherscan-api-key ${ETHERSCAN_API_KEY} \
	--broadcast

aderyn :; aderyn .
