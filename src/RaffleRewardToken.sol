//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {ERC20} from "@openzeppelin-contracts/ERC20/ERC20.sol";

contract RaffleRewardToken is ERC20 {
    uint256 constant TOTAL_SUPPLY = 100_000_000 ether;
    constructor(address _owner) ERC20("RaffleTicket", "RTK") {
        _mint(_owner, TOTAL_SUPPLY);
    }
}
