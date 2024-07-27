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

  /// @notice Create request for selling UAHc with exact amount of UAHc tokens to sell
  /// @dev This function fill send request to Chainlink Function in order to find out the real USD/UAH rate
  /// @param _exchangeToken Address of exchange token to receive
  /// @param _uahAmountToSell Amount of UAHc to sell
  /// @param _seller Address of seller
  /// @param _minAmountOut Minimum amount of exchange token to receive
  /// @return requestId id of the Chainlink Function request
  // function makeSellWithAmountInRequest(
  //   address _exchangeToken,
  //   uint256 _uahAmountToSell,
  //   address _seller,
  //   uint256 _minAmountOut
  // )
  //   external
  //   returns (bytes32 requestId);

  /// @notice Create request for buying UAHc with exact amount of exchange token
  /// @dev This function fill send request to Chainlink Function in order to find out the real USD/UAH rate
  /// @param _exchangeToken Address of exchange token
  /// @param _tokenAmount Amount of exchange token
  /// @param _buyer Address of buyer
  /// @param _minAmountOut Minimum amount of UAHc to receive
  /// @return requestId id of the Chainlink Function request
  function makeBuyWithAmountInRequest(
    address _exchangeToken,
    uint256 _tokenAmount,
    address _buyer,
    uint256 _minAmountOut
  )
    external
    returns (bytes32 requestId);

  /// @notice This method allows to set exchange token with price feed (Token/USD)
  /// @dev This method MUST be called by the owner of the contract only
  /// @param _exchangeToken Address of exchange token
  /// @param _usdPriceFeed Address of price feed (Token/USD)
  function addNewExchangeToken(address _exchangeToken, address _usdPriceFeed) external;

  /// @notice Get the UAH Coin liquidity (UAH Coin balance - locked UAH Coin)
  /// @return UAH Coin liquidity
  function getUahCoinLiquidity() external view returns (uint256);

  /// @notice Get the exchange rate for the given token by knowing the USD/UAH exchange rate (off-chain data)
  /// @param _exchangeToken The token to get the exchange rate for
  /// @param _usdToUahExchangeRate The USD/UAH exchange rate (1 USD = _usdToUahExchangeRate UAH)
  function getExchangeRateForToken(
    address _exchangeToken,
    uint256 _usdToUahExchangeRate
  )
    external
    view
    returns (uint256);

  /// @notice Estimate the amount of UAHc to receive for the given amount of exchange token
  /// @param _exchangeToken The token to get the exchange rate for
  /// @param _tokenAmount The amount of exchange token
  /// @param _usdToUahExchangeRate The USD/UAH exchange rate (1 USD = _usdToUahExchangeRate UAH)
  /// @return The amount of UAHc to receive
  function estimateBuyAmountOut(
    address _exchangeToken,
    uint256 _tokenAmount,
    uint256 _usdToUahExchangeRate
  )
    external
    view
    returns (uint256);
}
