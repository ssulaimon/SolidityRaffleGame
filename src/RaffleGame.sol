//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {PriceConverter} from "./library/PriceConverter.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink-brownie-contracts/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink-brownie-contracts/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink-brownie-contracts/contracts/interfaces/AutomationCompatibleInterface.sol";
import {IERC20} from "@openzeppelin-contracts/ERC20/IERC20.sol";
contract RaffleGame is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /**Custom Errors */
    error RaffleGame__NotOwner(address caller);
    error RaffGame_NotEnoughEntryAmount(uint256 amount);
    error RaffleGame__AlreadyEnteredRaffle(address player);
    error RaffleGame__RaffleIsNotOpen();
    error RaffleGame__NotEnoughPlayer();
    error RaffleGame__NotYetTime(uint256 time);
    error RaffleGame__NotEnoughContractBalance();
    error RaffleGame__UpKeepIsNotNeeded(
        uint256 playersLenght,
        uint256 balance,
        RaffleGameState gameState,
        uint256 interval
    );
    error RaffleGame__InvalidRequestId(uint256 requestId);
    error RaffleGame__InsufficientRewardEarned();
    error RaffleGame__TransactionFailed();

    /**library */
    using PriceConverter for uint256;

    /**Enums */

    enum RaffleGameState {
        OPEN,
        CLOSED,
        PAUSED,
        CALCULATING
    }

    event EnteredRaffle(address player, uint256 amount);
    address private immutable i_aggregatorV3InterfaceAddress;
    uint256 private s_entryFee;
    address private i_owner;
    address payable[] private s_players;
    RaffleGameState private s_raffleGameState;

    uint16 private constant CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private constant GAS_LIMIT = 500000;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subId;
    uint256 private s_interval = 1800;
    uint256 private s_lastRaffleDraw;
    uint256 private s_requestId;
    address private s_rewardTokenAddress;
    IERC20 private s_rewardToken;
    uint256 private s_rewardTokenSupply = 100_000_000 ether;
    address private s_latestWinner;

    mapping(address => uint256) s_earnedRewardToken;

    mapping(address => bool) s_addressAlreadyEntered;

    /** 
    @dev constructor
    @param _entryFee USD minimum entry fee for the lottey
    @param _aggregatorV3InterfaceAddress chainlink pricefeed contract addresss
     */

    constructor(
        uint256 _entryFee,
        address _aggregatorV3InterfaceAddress,
        address _vrfCoordinatorV2PlusAddress,
        bytes32 _keyHash,
        uint256 _subId
    ) VRFConsumerBaseV2Plus(_vrfCoordinatorV2PlusAddress) {
        i_owner = msg.sender;
        s_entryFee = _entryFee * 10 ** 18;
        i_aggregatorV3InterfaceAddress = _aggregatorV3InterfaceAddress;
        s_raffleGameState = RaffleGameState.OPEN;
        i_keyHash = _keyHash;
        i_subId = _subId;
        s_lastRaffleDraw = block.timestamp;
    }

    modifier isOwner() {
        if (msg.sender != i_owner) {
            revert RaffleGame__NotOwner(msg.sender);
        }

        _;
    }

    /**
    @dev This checks amount sent is enough to enter the lotter, checks if the sender have already entered the lottery before, checks if the raffle ganme is open
     */

    modifier feeAndDoubleEntryGameStateChecker() {
        uint256 baseMinimumAssetEntry = s_entryFee.convert(
            i_aggregatorV3InterfaceAddress
        );
        if (msg.value < baseMinimumAssetEntry) {
            revert RaffGame_NotEnoughEntryAmount(msg.value);
        }
        if (s_addressAlreadyEntered[msg.sender] == true) {
            revert RaffleGame__AlreadyEnteredRaffle(msg.sender);
        }
        if (s_raffleGameState != RaffleGameState.OPEN) {
            revert RaffleGame__RaffleIsNotOpen();
        }
        _;
    }

    // This function is called to enter the raffle game

    function enterRaffleGame()
        public
        payable
        feeAndDoubleEntryGameStateChecker
    {
        if (s_rewardTokenSupply > 10 ether) {
            s_earnedRewardToken[msg.sender] += 10 ether;
            s_rewardTokenSupply -= 10 ether;
        }
        s_addressAlreadyEntered[msg.sender] = true;
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender, msg.value);
    }

    receive() external payable {
        enterRaffleGame();
    }
    fallback() external payable {
        enterRaffleGame();
    }

    /**
    @dev this function checks if enough palyers is in the lottery, the lottery is opened, interval for new draw is met and enough balance is in contract 
     */
    function isUpKeepNeeded() internal view returns (bool) {
        if (s_players.length < 1) {
            revert RaffleGame__NotEnoughPlayer();
        }
        if (s_raffleGameState != RaffleGameState.OPEN) {
            revert RaffleGame__RaffleIsNotOpen();
        }
        if ((block.timestamp - s_lastRaffleDraw) < s_interval) {
            revert RaffleGame__NotYetTime(block.timestamp - s_lastRaffleDraw);
        }
        if (address(this).balance < 1) {
            revert RaffleGame__NotEnoughContractBalance();
        }
        return true;
    }

    /**
    @dev this function is called by chainlink automation
     */

    function checkUpkeep(
        bytes calldata /*checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = isUpKeepNeeded();
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData */) external override {
        s_requestId = getRandomNumber();
    }

    function getRandomNumber() internal returns (uint256) {
        bool isNeeded = isUpKeepNeeded();
        if (!isNeeded) {
            revert RaffleGame__UpKeepIsNotNeeded(
                s_players.length,
                address(this).balance,
                s_raffleGameState,
                (block.timestamp - s_lastRaffleDraw)
            );
        }
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: CONFIRMATION,
                callbackGasLimit: GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_raffleGameState = RaffleGameState.CALCULATING;
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        if (address(this).balance <= 0) {
            revert RaffleGame__NotEnoughContractBalance();
        }
        if (s_players.length <= 0) {
            revert RaffleGame__NotEnoughPlayer();
        }
        if (s_requestId == 0 || requestId != s_requestId) {
            revert RaffleGame__InvalidRequestId(requestId);
        }
        if (s_raffleGameState != RaffleGameState.CALCULATING) {
            revert RaffleGame__NotYetTime(0);
        }
        if ((block.timestamp - s_lastRaffleDraw) < s_interval) {
            revert RaffleGame__NotYetTime(block.timestamp - s_lastRaffleDraw);
        }

        uint256 pickedWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[pickedWinner];

        if (s_rewardTokenSupply > 20 ether) {
            s_earnedRewardToken[winner] += 20 ether;
            s_rewardTokenSupply -= 20 ether;
        }
        (bool transfered, ) = winner.call{value: address(this).balance}("");
        if (!transfered) {
            revert RaffleGame__TransactionFailed();
        }

        for (uint256 index = 0; index < s_players.length; index++) {
            address player = s_players[index];
            s_addressAlreadyEntered[player] = false;
        }
        s_latestWinner = winner;
        s_players = new address payable[](0);
        s_raffleGameState = RaffleGameState.OPEN;
    }

    function claimRewardToken(uint256 _amount) public {
        if (_amount > s_earnedRewardToken[msg.sender]) {
            revert RaffleGame__InsufficientRewardEarned();
        }
        s_rewardToken.transfer(msg.sender, _amount);
        s_earnedRewardToken[msg.sender] -= _amount;
    }

    /**
    Setters
     */

    function setRewardTokenDetails(address _rewardTokenAddress) public isOwner {
        s_rewardToken = IERC20(_rewardTokenAddress);

        s_rewardTokenAddress = _rewardTokenAddress;
    }

    function setNewEntryFee(uint256 _newEntryFee) public isOwner {
        s_entryFee = _newEntryFee;
    }

    function setGameState(RaffleGameState _newRaffleGameState) public isOwner {
        s_raffleGameState = _newRaffleGameState;
    }

    function setNewInterval(uint256 _newInterval) public isOwner {
        s_interval = _newInterval;
    }

    /**
    Getters
     */

    // Get connversion of base (ETH or BNB) asset from USD

    function getBaseAssetEntryFee() public view returns (uint256) {
        uint256 ethEntryFee = s_entryFee.convert(
            i_aggregatorV3InterfaceAddress
        );
        return ethEntryFee;
    }

    //Get the entryFee in USD
    function getUSEntryFee() public view returns (uint256) {
        return s_entryFee;
    }
    // Get contract owner address
    function getOwnerAddress() public view returns (address) {
        return i_owner;
    }

    function getAddressAlreadyEntered(
        address _address
    ) public view returns (bool) {
        return s_addressAlreadyEntered[_address];
    }

    function getPlayers() public view returns (address payable[] memory) {
        return s_players;
    }

    function getRaffleGameState() public view returns (RaffleGameState) {
        return s_raffleGameState;
    }
    function getInterval() public view returns (uint256) {
        return s_interval;
    }
    function getRequestId() public view returns (uint256) {
        return s_requestId;
    }

    function getRewardTokenBalance() public view returns (uint256) {
        return s_rewardTokenSupply;
    }

    function getEarnedTokenAmount(
        address _address
    ) public view returns (uint256) {
        return s_earnedRewardToken[_address];
    }

    function getLatestWinner() public view returns (address) {
        return s_latestWinner;
    }
    function getRewardTokenAddress() public view returns (address) {
        return s_rewardTokenAddress;
    }

    function getRewardTokenContractBalance() public view returns (uint256) {
        return s_rewardToken.balanceOf(address(this));
    }
}
