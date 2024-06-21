//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {MockV3Aggregator} from "@mocks/AggregatorV3Mock.sol";
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-brownie-contracts/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
contract DeployDependencies is Script {
    // address _vrfCoordinatorV2PlusAddress,
    //     bytes32 _keyHash
    struct DeploymentConfig {
        address priceFeed;
        uint256 entryFee;
        uint256 privateKey;
        address vrfCoordinatorAddress;
        bytes32 keyHash;
        uint256 subId;
    }
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant BNB_TESTNET_CHAIN_ID = 97;
    address constant SEPOLIA_VRF_ADDRESS =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 constant SEPOLIA_KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address constant BNB_TESTNET_VRF_ADDRESS =
        0xDA3b641D438362C440Ac5458c57e00a712b66700;
    bytes32 constant BNB_TESTNET_KEY_HASH =
        0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26;
    uint256 BNB_TESTNET_SUB_ID =
        26046708221726870780817433006403971575168733530957654586379603357975313979400;
    uint256 SEPOLIA_SUB_ID =
        30758505892170160297377090563337759430077303035815999089751954221081870277149;
    uint64 internal constant BASE_FEE = 100000000000000000;
    uint64 internal constant GAS_LANE = 1e9;
    int256 internal constant LINK = 1000000000;

    uint8 constant DECIMAL = 8;
    int256 constant INITIAL_ANSWER = 3000 * 10 ** 8;
    uint256 immutable EVM_PRIVATE_KEY = vm.envUint("EVM_PRIVATE_KEY");
    uint256 immutable ANVIL_PRIVATE_KEY = vm.envUint("ANVIL_PRIVATE_KEY");

    //$20
    uint256 constant ENTRY_FEE = 20;

    //ETH/USD
    address constant SEPOLIA_ETH_PRICE_FEED_ADDRES =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;
    //BNB/USD
    address constant BNB_TESTNET_BNB_PRICE_FEED_ADDRESS =
        0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
    DeploymentConfig public i_deploymentConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            i_deploymentConfig = sepoliaConfig();
        } else if (block.chainid == BNB_TESTNET_CHAIN_ID) {
            i_deploymentConfig = bnbTestnetConfig();
        } else {
            i_deploymentConfig = anvilConfig();
        }
    }

    function sepoliaConfig() internal view returns (DeploymentConfig memory) {
        DeploymentConfig memory deploymentConfig = DeploymentConfig({
            priceFeed: SEPOLIA_ETH_PRICE_FEED_ADDRES,
            entryFee: ENTRY_FEE,
            privateKey: EVM_PRIVATE_KEY,
            vrfCoordinatorAddress: SEPOLIA_VRF_ADDRESS,
            keyHash: SEPOLIA_KEY_HASH,
            subId: SEPOLIA_SUB_ID
        });
        return deploymentConfig;
    }

    function bnbTestnetConfig()
        internal
        view
        returns (DeploymentConfig memory)
    {
        DeploymentConfig memory deploymentConfig = DeploymentConfig({
            priceFeed: BNB_TESTNET_BNB_PRICE_FEED_ADDRESS,
            entryFee: ENTRY_FEE,
            privateKey: EVM_PRIVATE_KEY,
            vrfCoordinatorAddress: BNB_TESTNET_VRF_ADDRESS,
            keyHash: BNB_TESTNET_KEY_HASH,
            subId: BNB_TESTNET_SUB_ID
        });
        return deploymentConfig;
    }

    function anvilConfig() internal returns (DeploymentConfig memory) {
        vm.startBroadcast(ANVIL_PRIVATE_KEY);
        MockV3Aggregator mockV3 = new MockV3Aggregator(DECIMAL, INITIAL_ANSWER);
        // uint96 _baseFee, uint96 _gasPrice, int256 _weiPerUnitLink
        VRFCoordinatorV2_5Mock vrfCoordiatorV2_5 = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_LANE,
            4072456973688207
        );
        uint256 mockSubId = vrfCoordiatorV2_5.createSubscription();
        vrfCoordiatorV2_5.fundSubscription(mockSubId, 40 ether);

        vm.stopBroadcast();
        DeploymentConfig memory deploymentConfig = DeploymentConfig({
            priceFeed: address(mockV3),
            entryFee: ENTRY_FEE,
            privateKey: ANVIL_PRIVATE_KEY,
            vrfCoordinatorAddress: address(vrfCoordiatorV2_5),
            keyHash: BNB_TESTNET_KEY_HASH,
            subId: mockSubId
        });
        return deploymentConfig;
    }
}
