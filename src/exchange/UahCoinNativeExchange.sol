// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ConfirmedOwner } from "@chainlink/contracts/shared/access/ConfirmedOwner.sol";
import { FunctionsClient } from "@chainlink/contracts/functions/dev/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/interfaces/AggregatorV3Interface.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TypesLib } from "../libraries/TypesLib.sol";
import { OracleLib } from "../libraries/OracleLib.sol";

import { IUahCoin } from "../interfaces/IUahCoin.sol";
import { IUahCoinNativeExchange } from "../interfaces/IUahCoinNativeExchange.sol";

/// @title UahCoinNativeExchange
/// @notice This contract is responsible for exchanging UAH Coin for other tokens. This contract will use Chainlink
/// Functions to get the UAH/USD exchange rate.
contract UahCoinNativeExchange is ConfirmedOwner, FunctionsClient, IUahCoinNativeExchange {
  using FunctionsRequest for FunctionsRequest.Request;

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  uint32 public constant FUNCTION_CALLBACK_GAS_LIMIT = 300_000;
  uint8 public constant PRICE_DECIMALS = 18;

  uint64 public immutable i_subscriptionId;
  bytes32 public immutable i_donId;
  IUahCoin public immutable i_uahCoin;

  /*//////////////////////////////////////////////////////////////
                                STATE
  //////////////////////////////////////////////////////////////*/

  string public s_getUsdExcahngeRateSourceCode;
  uint8 private s_secretsSlotId;
  uint64 private s_secretsVersion;

  // This UahCoinNativeExchange uses Chainlink functions to get the UAH/USD exchange rate
  // Until the exchange rate is received, the UAH Coin will be locked
  uint256 public s_lockedUahCoin;
  uint256 public s_minimumBuyAmount;

  /// @notice This tokens are used to buy or sell UAH Coin
  mapping(address token => AggregatorV3Interface usdPriceFeed) public s_exchangeTokenToUsdPriceFeed;
  mapping(bytes32 requestId => TypesLib.BuyRequest) private s_requestIdToBuyRequest;

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  error UahCoinNativeExchange__ExchangeTokenNotSupported(address token);
  error UahCoinNativeExchange__LessThanMinimumAmount(uint256 amount);
  error UahCoinNativeExchange__NotEnoughExchangeLiquidity(uint256 currentLiquidity);
  error UahCoinNativeExchange__ZeroAddressProvided();
  error UahCoinNativeExchange__ZeroValueProvided();
  error UahCoinNativeExchange__ExchangeTokenTransferFailed();
  error UahCoinNativeExchange__UnknownRequestId();

  /*//////////////////////////////////////////////////////////////
                              MODIFIERS
  //////////////////////////////////////////////////////////////*/

  constructor(
    address _confirmedOwner,
    IUahCoin _uahCoin,
    uint256 _minimumBuyAmount,
    address _functionRouter,
    uint64 _subscriptionId,
    bytes32 _donId,
    string memory _getUsdExcahngeRateSourceCode,
    uint8 _secretsSlotId,
    uint64 _secretsVersion
  )
    ConfirmedOwner(_confirmedOwner)
    FunctionsClient(_functionRouter)
  {
    i_uahCoin = _uahCoin;
    s_minimumBuyAmount = _minimumBuyAmount;
    i_subscriptionId = _subscriptionId;
    i_donId = _donId;
    s_getUsdExcahngeRateSourceCode = _getUsdExcahngeRateSourceCode;
    s_secretsSlotId = _secretsSlotId;
    s_secretsVersion = _secretsVersion;
  }

  /// @inheritdoc IUahCoinNativeExchange
  function addNewExchangeToken(address _exchangeToken, address _usdPriceFeed) external onlyOwner {
    if (_exchangeToken == address(0) || _usdPriceFeed == address(0)) {
      revert UahCoinNativeExchange__ZeroAddressProvided();
    }
    s_exchangeTokenToUsdPriceFeed[_exchangeToken] = AggregatorV3Interface(_usdPriceFeed);
  }

  /// @inheritdoc IUahCoinNativeExchange
  function makeBuyWithAmountInRequest(
    address _exchangeToken,
    uint256 _tokenAmount,
    address _buyer,
    uint256 _minAmountOut
  )
    external
    returns (bytes32 requestId)
  {
    if (_exchangeToken == address(0) || _buyer == address(0)) {
      revert UahCoinNativeExchange__ZeroAddressProvided();
    }

    if (_tokenAmount == 0) {
      revert UahCoinNativeExchange__ZeroValueProvided();
    }

    if (address(s_exchangeTokenToUsdPriceFeed[_exchangeToken]) == address(0)) {
      revert UahCoinNativeExchange__ExchangeTokenNotSupported(_exchangeToken);
    }

    if (_minAmountOut < s_minimumBuyAmount) {
      revert UahCoinNativeExchange__LessThanMinimumAmount(_minAmountOut);
    }

    uint256 currentLiquidity = _getUahCoinLiquidity();
    if (currentLiquidity == 0 || currentLiquidity < _minAmountOut) {
      revert UahCoinNativeExchange__NotEnoughExchangeLiquidity(currentLiquidity);
    }

    FunctionsRequest.Request memory req;
    req.addDONHostedSecrets(s_secretsSlotId, s_secretsVersion);
    req.initializeRequestForInlineJavaScript(s_getUsdExcahngeRateSourceCode);

    bytes32 reqId = _sendRequest(req.encodeCBOR(), i_subscriptionId, FUNCTION_CALLBACK_GAS_LIMIT, i_donId);
    s_requestIdToBuyRequest[reqId] = TypesLib.BuyRequest({
      minAmountOut: _minAmountOut,
      buyer: _buyer,
      tokenAmount: _tokenAmount,
      exchangeToken: _exchangeToken
    });
    s_lockedUahCoin += _minAmountOut;

    bool success = IERC20(_exchangeToken).transferFrom(_buyer, address(this), _tokenAmount);
    if (!success) {
      revert UahCoinNativeExchange__ExchangeTokenTransferFailed();
    }

    return reqId;
  }

  /// @inheritdoc IUahCoinNativeExchange
  function getUahCoinLiquidity() external view returns (uint256) {
    return _getUahCoinLiquidity();
  }

  /// @notice Get the buy request by the given request ID
  function getBuyRequest(bytes32 _requestId) external view returns (TypesLib.BuyRequest memory) {
    return s_requestIdToBuyRequest[_requestId];
  }

  /// @inheritdoc IUahCoinNativeExchange
  function getExchangeRateForToken(
    address _exchangeToken,
    uint256 _usdToUahExchangeRate
  )
    external
    view
    returns (uint256)
  {
    return _calculateExchangeRateForToken(_exchangeToken, _usdToUahExchangeRate);
  }

  /// @inheritdoc IUahCoinNativeExchange
  function estimateBuyAmountOut(
    address _exchangeToken,
    uint256 _tokenAmount,
    uint256 _usdToUahExchangeRate
  )
    external
    view
    returns (uint256)
  {
    uint256 exchangeRateForToken = _calculateExchangeRateForToken(_exchangeToken, _usdToUahExchangeRate);
    return _tokenAmount * exchangeRateForToken / 10 ** PRICE_DECIMALS;
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    _filfillBuyRequest(requestId, response, err);
  }

  function _filfillBuyRequest(bytes32 _requestId, bytes memory _response, bytes memory _err) internal {
    TypesLib.BuyRequest memory buyRequest = s_requestIdToBuyRequest[_requestId];

    if (buyRequest.buyer == address(0)) {
      // If the buyer is zero address, the request is not exist
      revert UahCoinNativeExchange__UnknownRequestId();
    }

    s_lockedUahCoin -= buyRequest.minAmountOut;

    if (_err.length != 0) {
      // If there is an error, unlock the UAH Coin and send the tokens back to the buyer
      IERC20(buyRequest.exchangeToken).transfer(buyRequest.buyer, buyRequest.tokenAmount);
      emit ExchangeRefunded(_requestId, RefundReason.FunctionFailed, _err);
      return;
    }

    uint256 usdToUahExchangeRate = _decodeFunctionResponse(_response);
    uint256 exchangeRateForToken = _calculateExchangeRateForToken(buyRequest.exchangeToken, usdToUahExchangeRate);
    uint256 uahAmount = buyRequest.tokenAmount * exchangeRateForToken / 10 ** PRICE_DECIMALS;

    if (uahAmount < buyRequest.minAmountOut) {
      // If the amount is less than the minimum amount, unlock the UAH Coin and send the tokens back to the buyer
      IERC20(buyRequest.exchangeToken).transfer(buyRequest.buyer, buyRequest.tokenAmount);
      emit ExchangeRefunded(_requestId, RefundReason.LessThanMinimumAmount, "");
      return;
    }

    uint256 uahCoinBalance = i_uahCoin.balanceOf(address(this));
    if (uahAmount > uahCoinBalance) {
      // If there is not enough UAH Coin, then send the all uah coin to the buyer
      uahAmount = uahCoinBalance;
    }

    i_uahCoin.transfer(buyRequest.buyer, uahAmount);
  }

  function _decodeFunctionResponse(bytes memory _response) internal pure returns (uint256 usdToUahExchangeRate) {
    usdToUahExchangeRate = abi.decode(_response, (uint256));
  }

  function _calculateExchangeRateForToken(
    address _exchangeToken,
    uint256 _usdToUahExchangeRate // 1 USD = _usdToUahExchangeRate UAH (ex. 1 USD = 40 UAH), 18 decimals
  )
    internal
    view
    returns (uint256)
  {
    // ex: 1 USD = 40 UAH
    //     1 LINK = 2 USD
    //     1 LINK = _usdToUahExchangeRate * usdToExchangeTokenRate UAH = 40 * 2 = 80 UAH

    uint256 usdToExchangeTokenRate = _getUsdExchangeRateForToken(_exchangeToken);
    return _usdToUahExchangeRate * usdToExchangeTokenRate / 10 ** OracleLib.PRICE_DECIMALS;
  }

  /// @notice Get the USD exchange rate for the given token (1 token = ? USD)
  /// @param _exchangeToken The token to get the exchange rate for
  function _getUsdExchangeRateForToken(address _exchangeToken) internal view returns (uint256) {
    AggregatorV3Interface priceFeed = s_exchangeTokenToUsdPriceFeed[_exchangeToken];
    if (address(priceFeed) == address(0)) {
      revert UahCoinNativeExchange__ExchangeTokenNotSupported(_exchangeToken);
    }

    (, int256 price,,,) = OracleLib.staleCheckLatestRoundData(priceFeed);
    return uint256(price);
  }

  /// @dev Get the UAH Coin liquidity (UAH Coin balance - locked UAH Coin)
  function _getUahCoinLiquidity() internal view returns (uint256) {
    return i_uahCoin.balanceOf(address(this)) - s_lockedUahCoin;
  }
}
