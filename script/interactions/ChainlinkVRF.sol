//SPDX-License-Identifier:MIT
import {VRFCoordinatorV2_5Mock} from "@chainlink-brownie-contracts/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Script} from "forge-std/Script.sol";
pragma solidity >=0.8.0 <0.9.0;

interface ChainlinkVRF2_5Interface {
    function addConsumer(uint256 subId, address consumer) external;

    function getSubscription(
        uint256 subId
    )
        external
        view
        returns (
            uint96 balance,
            uint96 nativeBalance,
            uint64 reqCount,
            address subOwner,
            address[] memory consumers
        );
}

contract ChainlinkInteraction is Script {
    function addConsumer(
        address vrfAddress,
        uint256 privateKey,
        uint256 subId,
        address consumer
    ) public {
        if (block.chainid == 31337) {
            VRFCoordinatorV2_5Mock vrf = VRFCoordinatorV2_5Mock(vrfAddress);
            vm.startBroadcast(privateKey);
            vrf.addConsumer(subId, consumer);
            vm.stopBroadcast();
        } else {
            ChainlinkVRF2_5Interface vrf = ChainlinkVRF2_5Interface(vrfAddress);
            vm.startBroadcast(privateKey);
            vrf.addConsumer(subId, consumer);
            vm.stopBroadcast();
        }
    }
    function run() external {}
}
