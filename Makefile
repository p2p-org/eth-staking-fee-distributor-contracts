-include .env

clean  :; forge clean

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

NETWORK_ARGS := --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvvv

deploy:
	@forge script script/Deploy.s.sol:Deploy $(NETWORK_ARGS)
