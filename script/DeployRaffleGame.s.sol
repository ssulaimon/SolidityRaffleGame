//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Script} from "forge-std/Script.sol";
import {RaffleGame} from "../src/RaffleGame.sol";
import {DeployDependencies} from "./dependencies/DeployDependencies.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink-brownie-contracts/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {ChainlinkInteraction} from "./interactions/ChainlinkVRF.sol";
import {RaffleRewardToken} from "../src/RaffleRewardToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DeployRaffleGame is Script {
    function run()
        external
        returns (RaffleGame, uint256, address, uint256, address)
    {
        DeployDependencies deployDependencies = new DeployDependencies();
        (
            address priceFeed,
            uint256 entryFee,
            uint256 privateKey,
            address vrf,
            bytes32 keyHash,
            uint256 subId
        ) = deployDependencies.i_deploymentConfig();
        vm.startBroadcast(privateKey);
        RaffleGame raffleGame = new RaffleGame(
            entryFee,
            priceFeed,
            vrf,
            keyHash,
            subId
        );
        // RaffleRewardToken rewardToken = new RaffleRewardToken(
        //     address(raffleGame)
        // );
        vm.stopBroadcast();
        ChainlinkInteraction chainlinkInteraction = new ChainlinkInteraction();
        chainlinkInteraction.addConsumer(
            vrf,
            privateKey,
            subId,
            address(raffleGame)
        );
        return (raffleGame, privateKey, vrf, subId, address(0));
    }
}

contract RewardToken is Script {
    function run() external returns (RaffleRewardToken) {
        address raffleContract = DevOpsTools.get_most_recent_deployment(
            "RaffleGame",
            block.chainid
        );
        vm.startBroadcast();
        RaffleRewardToken raffleToken = new RaffleRewardToken(raffleContract);
        vm.stopBroadcast();
        return raffleToken;
    }
}
