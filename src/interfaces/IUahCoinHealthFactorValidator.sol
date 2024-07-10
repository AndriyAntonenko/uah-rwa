// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IUahCoinHealthFactorValidator {
  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  event ValidationRequestSent(bytes32 indexed requestId, address indexed validator);
  event ValidationIntervalHasBeenChanged(uint64 newValidationInterval);
  event GetOffChainCollateralSourceCodeUpdated();

  /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Sends a Chainlink Functions request to validate the health factor
  /// @dev This method MUST emit a ValidationRequestSent event
  /// @return requestId The ID of the Chainlink Functions request
  function sendValidationRequest() external returns (bytes32);

  /// @notice updates the off-chain collateral source code
  /// @dev Only the owner can call this method. This method must emit a GetOffChainCollateralSourceCodeUpdated event
  /// @param _sourceCode The new off-chain collateral source code
  function updateGetOffChainCollateralSourceCode(string memory _sourceCode) external;
}
