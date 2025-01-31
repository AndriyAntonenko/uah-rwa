// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { TypesLib } from "../libraries/TypesLib.sol";

interface IUahCoin is IERC20, IERC20Metadata {
  event HealthFactorUpdated(bool indexed isHealthy, uint256 indexed healthFactor);
  event GetOffChainCollateralSourceCodeUpdated();
  event Withdrawn(address indexed to, uint256 indexed amount);
  event SecretsUpdated(uint8 indexed slotId, uint64 indexed version);

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

  /// @notice updates the off-chain collateral source code
  /// @dev Only the owner can call this method. This method must emit a GetOffChainCollateralSourceCodeUpdated event
  /// @param _sourceCode The new off-chain collateral source code
  function updateGetOffChainCollateralSourceCode(string memory _sourceCode) external;

  /// @notice Withdraw minted UahCoin tokens to the specified address
  /// @dev Only the owner can call this method. This method MUST emit a Withdrawn event
  /// @param _to The address to withdraw the UahCoin tokens to
  /// @param _amount The amount of UahCoin tokens to withdraw
  function withdraw(address _to, uint256 _amount) external;

  /// @notice updates the chainlink function secrets slot ID and version
  /// @dev Only the owner can call this method. This method MUST emit a SecretsUpdated event
  /// @param _slotId The new chainlink function secrets slot ID
  /// @param _version The new chainlink function secrets version
  function updateSecrets(uint8 _slotId, uint64 _version) external;
}
