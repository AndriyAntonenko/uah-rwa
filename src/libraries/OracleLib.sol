/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AggregatorV3Interface } from "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";

library OracleLib {
  error OracleLib__StalePrice();

  uint256 public constant PRICE_DECIMALS = 8;
  uint256 private constant TIMEOUT = 1 hours;

  function staleCheckLatestRoundData(AggregatorV3Interface _chainlinkFeed)
    public
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    (roundId, answer, startedAt, updatedAt, answeredInRound) = _chainlinkFeed.latestRoundData();

    if (updatedAt == 0 || answeredInRound < roundId || block.timestamp - updatedAt > TIMEOUT) {
      revert OracleLib__StalePrice();
    }
  }
}
