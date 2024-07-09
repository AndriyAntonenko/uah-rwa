// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { TypesLib } from "../libraries/TypesLib.sol";

interface IUahCoin is IERC20, IERC20Metadata {
  event HealthFactorUpdated(bool indexed isHealthy, uint256 indexed healthFactor);

  /// @notice Sends a Chainlink Functions request to mint UahCoin tokens
  /// @param _amount The amount of UahCoin tokens to mint
  /// @return requestId The ID of the Chainlink Functions request
  function sendMintRequest(uint256 _amount) external returns (bytes32);

  /// @notice Calculate current health factor based on the approved off-chain collateral. Only
  /// UahCoinHealthFactorValidator can call this method
  /// @dev This method must emit a HealthFactorUpdated event
  /// @param _approvedOffChainCollateral The approved off-chain collateral
  /// @return isHealthy True if the health factor is above the threshold, false otherwise
  /// @return healthFactor The current health factor
  function validateHealthFactor(uint256 _approvedOffChainCollateral)
    external
    returns (bool isHealthy, TypesLib.HealthFactor memory healthFactor);
}
