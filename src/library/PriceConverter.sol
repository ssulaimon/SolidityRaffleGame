//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {AggregatorV3Interface} from "@chainlink-brownie-contracts/contracts/interfaces/AggregatorV3Interface.sol";

/*
@title Price converter
@author Sulaimon
@details Convert dollar to value in base asset
 */
library PriceConverter {
    function latestEthPrice(
        address aggregatorV3Address
    ) internal view returns (uint256) {
        AggregatorV3Interface aggregatorV3Interface = AggregatorV3Interface(
            aggregatorV3Address
        );
        (, int256 answer, , , ) = aggregatorV3Interface.latestRoundData();
        uint256 latestPrice = uint256(answer) * 10 ** 10;
        return latestPrice;
    }
    /*
    @param amount the USD 
    @param aggregatorV3Address chainlink pricefeed contractAddress 
     */
    function convert(
        uint256 amount,
        address aggregatorV3Address
    ) public view returns (uint256) {
        uint256 latestPrice = latestEthPrice(aggregatorV3Address);
        uint256 amountToEth = (amount * 10 ** 18) / latestPrice;
        return amountToEth;
    }
}
