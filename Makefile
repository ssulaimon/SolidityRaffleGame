-include .env
build:; forge build

deploybnb:
	forge script script/DeployRaffleGame.s.sol:DeployRaffleGame --rpc-url $(SEPOLIA_RPC_URL) --private-key $(EVM_PRIVATE_KEY) --broadcast --legacy --verify --etherscan-api-key $(ETHER_SCAN)

deployrewardToken:
	forge script script/DeployRaffleGame.s.sol:RewardToken --rpc-url $(SEPOLIA_RPC_URL) --private-key $(EVM_PRIVATE_KEY) --broadcast --legacy --verify --etherscan-api-key $(ETHER_SCAN)