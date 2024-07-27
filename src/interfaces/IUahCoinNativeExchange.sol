// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IUahCoinNativeExchange {
  enum RefundReason {
    FunctionFailed,
    LessThanMinimumAmount
  }

  /// @notice Event emitted in two possible cases of refund:
  /// 1. Chainlink function execution failed
  /// 2. UAHc amount is less than minimum amount provided by buyer
  /// In both cases, buyer will receive back his exchange tokens and event will be emitted for off-chain processing
  event ExchangeRefunded(bytes32 indexed requestId, RefundReason indexed reason, bytes data);

  /// @notice Create request for buying UAHc with exact amount of exchange token
  /// @dev This function fill send request to Chainlink Function in order to find out the real USD/UAH rate
  /// @param _exchangeToken Address of exchange token
  /// @param _tokenAmount Amount of exchange token
  /// @param _buyer Address of buyer
  /// @param _minAmountOut Minimum amount of UAHc to receive
  function makeBuyWithAmountInRequest(
    address _exchangeToken,
    uint256 _tokenAmount,
    address _buyer,
    uint256 _minAmountOut
  )
    external
    returns (bytes32 requestId);
}
