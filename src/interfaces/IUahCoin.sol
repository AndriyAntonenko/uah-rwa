// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUahCoin is IERC20, IERC20Metadata {
  /// @notice Sends a Chainlink Functions request to mint UahCoin tokens
  /// @param _amount The amount of UahCoin tokens to mint
  /// @return requestId The ID of the Chainlink Functions request
  function sendMintRequest(uint256 _amount) external returns (bytes32);
}
