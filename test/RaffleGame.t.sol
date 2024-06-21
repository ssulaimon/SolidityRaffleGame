//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffleGame} from "../script/DeployRaffleGame.s.sol";
import {RaffleGame} from "../src/RaffleGame.sol";
import {ChainlinkVRF2_5Interface} from "../script/interactions/ChainlinkVRF.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-brownie-contracts/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IERC20} from "@openzeppelin-contracts/ERC20/IERC20.sol";

contract RaffleGameTest is Test {
    RaffleGame raffleGame;
    uint256 privateKey;
    address vrfAddress;
    address newUser;
    uint256 subId;
    uint256 constant INTERVAL = 1800;
    uint256 constant REWARD_SUPPLY = 100_000_000 ether;
    address rewardTokenAddress;

    function setUp() external {
        DeployRaffleGame deployRaffleGame = new DeployRaffleGame();
        (
            raffleGame,
            privateKey,
            vrfAddress,
            subId,
            rewardTokenAddress
        ) = deployRaffleGame.run();
        newUser = makeAddr("newUser");
        vm.deal(newUser, 1 ether);
    }

    function testEntryFee() public view {
        uint256 ethPrice = raffleGame.getBaseAssetEntryFee();
        console.log(ethPrice);
        assert(ethPrice > 0.005 ether);
    }

    function testOwner() public view {
        address owner = raffleGame.getOwnerAddress();
        address ownerAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        assert(newUser != owner);
        assertEq(ownerAddress, owner);
    }

    function testNotOwnerCaller() public {
        vm.expectRevert();
        vm.prank(newUser);
        raffleGame.setNewEntryFee(50);
    }

    function testOwnerChangeEntryFee() public {
        vm.broadcast(privateKey);
        raffleGame.setNewEntryFee(50);
        assertEq(raffleGame.getUSEntryFee(), 50);
    }

    function testLowAmountEntry() public {
        vm.expectRevert();
        vm.prank(newUser);
        raffleGame.enterRaffleGame{value: 0.004 ether}();
    }

    modifier newUserEnterLottery() {
        vm.prank(newUser);
        raffleGame.enterRaffleGame{value: 0.1 ether}();
        _;
    }

    function testUserDoubleEntry() public newUserEnterLottery {
        vm.prank(newUser);
        vm.expectRevert();
        raffleGame.enterRaffleGame{value: 0.1 ether}();
        vm.stopPrank();
    }
    function testEntry() public newUserEnterLottery {
        bool alreadyEntered = raffleGame.getAddressAlreadyEntered(newUser);
        uint256 players = raffleGame.getPlayers().length;

        assertEq(alreadyEntered, true);
        assertEq(players, 1);
        assert(
            raffleGame.getRaffleGameState() == RaffleGame.RaffleGameState.OPEN
        );
    }

    function testLotteryNotOpen() public {
        vm.broadcast(privateKey);
        raffleGame.setGameState(RaffleGame.RaffleGameState.CLOSED);
        vm.expectRevert();
        vm.prank(newUser);
        raffleGame.enterRaffleGame{value: 0.1 ether}();
    }
    function testContractAddedToConsumer() public view {
        ChainlinkVRF2_5Interface chainlinkVRF = ChainlinkVRF2_5Interface(
            vrfAddress
        );
        (, , , , address[] memory consumers) = chainlinkVRF.getSubscription(
            subId
        );
        assert(consumers[0] == address(raffleGame));
    }

    function testNotYetTime() public newUserEnterLottery {
        vm.expectRevert();
        raffleGame.performUpkeep("");
        vm.stopPrank();
    }
    function testInterval() public {
        vm.startPrank(newUser);
        raffleGame.enterRaffleGame{value: 0.1 ether}();
        vm.warp(block.timestamp + INTERVAL + 1);
        raffleGame.performUpkeep("");
        vm.stopPrank();
    }
    function testNotOwnerChangeInterval() public {
        vm.expectRevert();
        vm.prank(newUser);
        raffleGame.setNewInterval(30);
    }

    function testOwnerChangeInterval() public {
        vm.broadcast(privateKey);
        raffleGame.setNewInterval(30);
        uint256 interval = raffleGame.getInterval();
        assertEq(interval, 30);
    }

    function testRequestId() public newUserEnterLottery {
        vm.warp(block.timestamp + INTERVAL + 1);
        raffleGame.performUpkeep("");
        uint256 requestId = raffleGame.getRequestId();
        assert(requestId != 0);
        vm.stopPrank();
    }

    function testRewardTokenSpply() public view {
        uint256 rewardSupply = raffleGame.getRewardTokenBalance();
        assert(rewardSupply == REWARD_SUPPLY);
    }

    function testRewardTokenReduced() public newUserEnterLottery {
        uint256 rewardTokenSupply = raffleGame.getRewardTokenBalance();
        uint256 earnedToken = raffleGame.getEarnedTokenAmount(newUser);
        assert((REWARD_SUPPLY - 10 ether) == rewardTokenSupply);
        assert(earnedToken == 10 ether);
    }

    function testInsufficientRewardTokenEarned() public newUserEnterLottery {
        vm.prank(newUser);
        vm.expectRevert();
        raffleGame.claimRewardToken(20 ether);
    }
    function testWithdrawEarnedRewardToken() public newUserEnterLottery {
        vm.broadcast(privateKey);
        raffleGame.setRewardTokenDetails(rewardTokenAddress);
        vm.startPrank(newUser);
        raffleGame.claimRewardToken(10 ether);
        uint256 rewardTokenBalance = raffleGame.getEarnedTokenAmount(newUser);
        assert(rewardTokenBalance == 0);
        vm.stopPrank();
    }

    function testRaffleCalculateAfterUpkeep() public newUserEnterLottery {
        vm.prank(newUser);
        vm.warp(block.timestamp + INTERVAL + 1);
        raffleGame.performUpkeep("");
        assert(
            raffleGame.getRaffleGameState() ==
                RaffleGame.RaffleGameState.CALCULATING
        );
    }

    function testSelectWinner() public {
        uint256 players = 10;
        for (uint256 index = 1; index < players; index++) {
            address playerAddress = address(uint160(index));
            vm.deal(playerAddress, 1 ether);
            vm.prank(playerAddress);
            raffleGame.enterRaffleGame{value: 0.5 ether}();
        }
        vm.startBroadcast(privateKey);
        vm.warp(block.timestamp + INTERVAL + 1);
        raffleGame.performUpkeep("");
        uint256 requestId = raffleGame.getRequestId();
        VRFCoordinatorV2_5Mock vrf = VRFCoordinatorV2_5Mock(vrfAddress);
        vrf.fulfillRandomWords(requestId, address(raffleGame));
        address winner = raffleGame.getLatestWinner();
        uint256 earnedToken = raffleGame.getEarnedTokenAmount(winner);
        uint256 playersLength = raffleGame.getPlayers().length;
        bool alreadyentered = raffleGame.getAddressAlreadyEntered(winner);
        console.log("Raffle Winner: ", winner);
        assert(earnedToken == 30 ether);
        assert(address(raffleGame).balance == 0);
        assert(playersLength == 0);
        assert(alreadyentered == false);

        vm.stopBroadcast();
    }

    function testRewardTokenAddress() public {
        vm.broadcast(privateKey);
        raffleGame.setRewardTokenDetails(rewardTokenAddress);
        address tokenAddress = raffleGame.getRewardTokenAddress();
        uint256 balance = raffleGame.getRewardTokenContractBalance();
        assertEq(tokenAddress, rewardTokenAddress);
        assertEq(balance, REWARD_SUPPLY);
    }
    function testClaimTokenOnContract() public newUserEnterLottery {
        IERC20 erc = IERC20(rewardTokenAddress);
        vm.broadcast(privateKey);
        raffleGame.setRewardTokenDetails(rewardTokenAddress);
        vm.prank(newUser);
        raffleGame.claimRewardToken(10 ether);
        uint256 contractBalance = raffleGame.getRewardTokenContractBalance();
        uint256 claimerBalance = erc.balanceOf(newUser);
        assert(contractBalance == REWARD_SUPPLY - 10 ether);
        assert(claimerBalance == 10 ether);
    }
    function testReceive() public {
        address raffleAddress = address(raffleGame);
        vm.prank(newUser);
        (bool success, ) = raffleAddress.call{value: 0.5 ether}("");
        assert(success == true);
        uint256 rafflePlayersLenght = raffleGame.getPlayers().length;
        assert(rafflePlayersLenght == 1);
    }
    function testAnotherRaffleRound() public newUserEnterLottery {
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.startPrank(newUser);
        raffleGame.performUpkeep("");
        uint256 requestId = raffleGame.getRequestId();
        VRFCoordinatorV2_5Mock vrf = VRFCoordinatorV2_5Mock(vrfAddress);
        vrf.fulfillRandomWords(requestId, address(raffleGame));
        vm.warp(block.timestamp + 1);
        raffleGame.enterRaffleGame{value: 0.01 ether}();
        uint256 playersLenght = raffleGame.getPlayers().length;
        assert(playersLenght == 1);
        vm.stopPrank();
    }
    function testCallAnotherRaffleRound() public {
        vm.startPrank(newUser);
        address raffGameAddress = address(raffleGame);
        (bool success, ) = raffGameAddress.call{value: 0.3 ether}("");
        assert(success == true);
        vm.warp(block.timestamp + INTERVAL + 1);
        raffleGame.performUpkeep("");
        uint256 requestId = raffleGame.getRequestId();
        VRFCoordinatorV2_5Mock vrf = VRFCoordinatorV2_5Mock(vrfAddress);
        vrf.fulfillRandomWords(requestId, address(raffleGame));
        vm.warp(block.timestamp + 1);
        payable(raffGameAddress).transfer(0.3 ether);
        // assert(successSecondEntry == true);
        uint256 playersLenght = raffleGame.getPlayers().length;
        assert(playersLenght == 1);
        assert(raffGameAddress.balance == 0.3 ether);
        vm.stopPrank();
    }
}
