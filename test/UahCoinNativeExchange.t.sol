// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockV3Aggregator } from "@chainlink/contracts/tests/MockV3Aggregator.sol";

import { UahCoinNativeExchange } from "../src/exchange/UahCoinNativeExchange.sol";
import { IUahCoinNativeExchange } from "../src/interfaces/IUahCoinNativeExchange.sol";
import { TypesLib } from "../src/libraries/TypesLib.sol";
import { DeployExchange } from "../script/DeployExchange.s.sol";
import { UahCoinBaseTest } from "./base/UahCoinBase.t.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";

contract UahCoinNativeExchangeTest is UahCoinBaseTest {
  address public immutable EXCHANGE_OWNER = makeAddr("EXCHANGE_OWNER");
  address public immutable BUYER = makeAddr("BUYER");
  uint256 public constant BUYER_EXCHANGE_TOKEN_BALANCE = 1000e18;
  uint256 public constant MINIMUM_BUY_AMOUNT = 1000e18;
  string public constant GET_USD_EXCHANGE_RATE_SOURCE_CODE = "function getUsdExchangeRate() { return 1; }";
  int256 public constant MOCK_TOKEN_ORACLE_INITIAL_ANSWER = 100_000_000_000;
  uint8 public constant MOCK_TOKEN_ORACLE_DECIMALS = 8;

  uint256 public constant EXCHANGE_TOKEN_USD_RATE = 2 * 10 ** MOCK_TOKEN_ORACLE_DECIMALS; // 2 USD
  uint256 public constant UAH_COIN_EXCHANGE_BALANCE = 1_000_000e18;

  UahCoinNativeExchange public exchange;
  ERC20Mock public exchangeToken;
  MockV3Aggregator public exchangeTokenUSDRateOracle;

  function setUp() public override {
    super.setUp();

    DeployExchange deployExchange = new DeployExchange();
    exchange = deployExchange.deploy(
      EXCHANGE_OWNER,
      address(uahCoin),
      MINIMUM_BUY_AMOUNT,
      address(functionsRouterMock),
      CHAINLINK_SUBSCRIPTION_ID,
      CHAINLINK_DON_ID,
      GET_USD_EXCHANGE_RATE_SOURCE_CODE,
      CHAINLINK_SECRET_SLOT_ID,
      CHAINLINK_SECRETS_VERSION
    );

    exchangeToken = new ERC20Mock("wETH", "wETH");
    exchangeTokenUSDRateOracle = new MockV3Aggregator(MOCK_TOKEN_ORACLE_DECIMALS, MOCK_TOKEN_ORACLE_INITIAL_ANSWER);
  }

  function test_setUp_successful() public view {
    assertEq(exchange.owner(), EXCHANGE_OWNER);
    assertEq(address(exchange.i_uahCoin()), address(uahCoin));
    assertEq(exchange.s_minimumBuyAmount(), MINIMUM_BUY_AMOUNT);
    assertEq(exchange.i_subscriptionId(), CHAINLINK_SUBSCRIPTION_ID);
    assertEq(exchange.i_donId(), CHAINLINK_DON_ID);
    assertEq(exchange.s_getUsdExcahngeRateSourceCode(), GET_USD_EXCHANGE_RATE_SOURCE_CODE);
  }

  function test_addNewExchangeToken_successful() public withMockExchangeToken {
    assertEq(
      address(exchange.s_exchangeTokenToUsdPriceFeed(address(exchangeToken))), address(exchangeTokenUSDRateOracle)
    );
  }

  function test_addNewExchangeToken_reverts_whenSenderIsNotOwner() public {
    address nonOwner = makeAddr("NON_OWNER");
    vm.expectRevert();
    vm.prank(nonOwner);
    exchange.addNewExchangeToken(address(exchangeToken), address(exchangeTokenUSDRateOracle));
  }

  function test_getExchangeRateForToken_successful() public withMockExchangeToken {
    uint256 usdToUahOffChainExchangeRate = 40 * 1e18; // 1 USD = 40 UAH
    uint256 exchangeRate = exchange.getExchangeRateForToken(address(exchangeToken), usdToUahOffChainExchangeRate);
    assertEq(exchangeRate, usdToUahOffChainExchangeRate * 2); // 1 TOKEN = 80 UAH
  }

  function test_getExchangeRateForToken_reverts_whenExchangeTokenNotSupported() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        UahCoinNativeExchange.UahCoinNativeExchange__ExchangeTokenNotSupported.selector, address(exchangeToken)
      )
    );
    exchange.getExchangeRateForToken(address(exchangeToken), 1e18);
  }

  function test_makeBuyWithAmountInRequest_successful()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 tokenAmount = BUYER_EXCHANGE_TOKEN_BALANCE;
    uint256 minAmountOut = UAH_COIN_EXCHANGE_BALANCE / 10;

    uint256 uahCoinExchangeBalance = uahCoin.balanceOf(address(exchange));
    uint256 exchangeBalanceBefore = exchangeToken.balanceOf(address(exchange));
    uint256 buyerBalanceBefore = exchangeToken.balanceOf(BUYER);

    vm.prank(BUYER);
    bytes32 requestId = exchange.makeBuyWithAmountInRequest(address(exchangeToken), tokenAmount, BUYER, minAmountOut);

    uint256 exchangeBalanceAfter = exchangeToken.balanceOf(address(exchange));
    uint256 buyerBalanceAfter = exchangeToken.balanceOf(BUYER);

    TypesLib.BuyRequest memory buyRequest = exchange.getBuyRequest(requestId);
    assertEq(buyRequest.minAmountOut, minAmountOut);
    assertEq(buyRequest.buyer, BUYER);
    assertEq(buyRequest.tokenAmount, tokenAmount);
    assertEq(buyRequest.exchangeToken, address(exchangeToken));
    assertEq(exchangeBalanceAfter, exchangeBalanceBefore + tokenAmount);
    assertEq(buyerBalanceAfter, buyerBalanceBefore - tokenAmount);
    assertEq(exchange.getUahCoinLiquidity(), uahCoinExchangeBalance - minAmountOut);
  }

  function test_makeBuyWithAmountInRequest_reverts_whenExchangeTokenNotSupported() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        UahCoinNativeExchange.UahCoinNativeExchange__ExchangeTokenNotSupported.selector, address(exchangeToken)
      )
    );
    exchange.makeBuyWithAmountInRequest(address(exchangeToken), 1e18, BUYER, 1e18);
  }

  function test_makeBuyWithAmountInRequest_reverts_whenMinAmountOutIsTooLow()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 minAmountOut = MINIMUM_BUY_AMOUNT - 1;
    vm.prank(BUYER);
    vm.expectRevert(
      abi.encodeWithSelector(UahCoinNativeExchange.UahCoinNativeExchange__LessThanMinimumAmount.selector, minAmountOut)
    );
    exchange.makeBuyWithAmountInRequest(address(exchangeToken), 1e18, BUYER, minAmountOut);
  }

  function test_makeBuyWithAmountInRequest_reverts_whenNotEnoughLiquidity()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 minAmountOut = exchange.getUahCoinLiquidity() + 1;
    vm.prank(BUYER);
    vm.expectRevert(
      abi.encodeWithSelector(
        UahCoinNativeExchange.UahCoinNativeExchange__NotEnoughExchangeLiquidity.selector, exchange.getUahCoinLiquidity()
      )
    );
    exchange.makeBuyWithAmountInRequest(address(exchangeToken), 1e18, BUYER, minAmountOut);
  }

  function test_fulfillBuyRequest_successful()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 usdToUahExchangeRate = 40 * 1e18; // 1 USD = 40 UAH
    uint256 tokenAmount = BUYER_EXCHANGE_TOKEN_BALANCE;
    uint256 minAmountOut = exchange.estimateBuyAmountOut(address(exchangeToken), tokenAmount, usdToUahExchangeRate);

    uint256 exchangeExchangeTokenBalanceBefore = exchangeToken.balanceOf(address(exchange));
    uint256 buyerExchangeTokenBalanceBefore = exchangeToken.balanceOf(BUYER);

    uint256 exchangeUahCoinBalanceBefore = uahCoin.balanceOf(address(exchange));
    uint256 buyerUahCoinBalanceBefore = uahCoin.balanceOf(BUYER);

    vm.prank(BUYER);
    bytes32 requestId = exchange.makeBuyWithAmountInRequest(address(exchangeToken), tokenAmount, BUYER, minAmountOut);

    vm.prank(address(functionsRouterMock));
    exchange.handleOracleFulfillment(requestId, abi.encode(usdToUahExchangeRate), "");

    uint256 exchangeExchangeTokenBalanceAfter = exchangeToken.balanceOf(address(exchange));
    uint256 buyerExchangeTokenBalanceAfter = exchangeToken.balanceOf(BUYER);

    uint256 exchangeUahCoinBalanceAfter = uahCoin.balanceOf(address(exchange));
    uint256 buyerUahCoinBalanceAfter = uahCoin.balanceOf(BUYER);

    assertEq(exchangeExchangeTokenBalanceAfter, exchangeExchangeTokenBalanceBefore + tokenAmount);
    assertEq(buyerExchangeTokenBalanceAfter, buyerExchangeTokenBalanceBefore - tokenAmount);
    assertEq(exchangeUahCoinBalanceAfter, exchangeUahCoinBalanceBefore - minAmountOut);
    assertEq(buyerUahCoinBalanceAfter, buyerUahCoinBalanceBefore + minAmountOut);
    assertEq(exchange.getUahCoinLiquidity(), exchangeUahCoinBalanceBefore - minAmountOut);
  }

  function test_fulfillBuyRequest_reverts_whenRequestIdIsUnknown()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 usdToUahExchangeRate = 40 * 1e18; // 1 USD = 40 UAH
    bytes32 requestId = bytes32(0);
    vm.expectRevert(abi.encodeWithSelector(UahCoinNativeExchange.UahCoinNativeExchange__UnknownRequestId.selector));
    vm.prank(address(functionsRouterMock));
    exchange.handleOracleFulfillment(requestId, abi.encode(usdToUahExchangeRate), "");
  }

  function test_fulfillBuyRequest_makeRefund_whenErrorReturnedByFunction()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 usdToUahExchangeRate = 40 * 1e18; // 1 USD = 40 UAH
    uint256 tokenAmount = BUYER_EXCHANGE_TOKEN_BALANCE;
    uint256 minAmountOut = exchange.estimateBuyAmountOut(address(exchangeToken), tokenAmount, usdToUahExchangeRate);

    vm.prank(BUYER);
    bytes32 requestId = exchange.makeBuyWithAmountInRequest(address(exchangeToken), tokenAmount, BUYER, minAmountOut);

    TypesLib.BuyRequest memory buyRequest = exchange.getBuyRequest(requestId);

    bytes memory err = "error";

    uint256 exchangeExchangeTokenBalanceBefore = exchangeToken.balanceOf(address(exchange));
    uint256 buyerExchangeTokenBalanceBefore = exchangeToken.balanceOf(BUYER);
    uint256 exchangeUahCoinLiquidityBefore = exchange.getUahCoinLiquidity();
    vm.prank(address(functionsRouterMock));
    exchange.handleOracleFulfillment(requestId, abi.encode(usdToUahExchangeRate), err);

    uint256 exchangeExchangeTokenBalanceAfter = exchangeToken.balanceOf(address(exchange));
    uint256 buyerExchangeTokenBalanceAfter = exchangeToken.balanceOf(BUYER);
    uint256 exchangeUahCoinLiquidityAfter = exchange.getUahCoinLiquidity();

    assertEq(exchangeExchangeTokenBalanceAfter, exchangeExchangeTokenBalanceBefore - buyRequest.tokenAmount);
    assertEq(buyerExchangeTokenBalanceAfter, buyerExchangeTokenBalanceBefore + buyRequest.tokenAmount);
    assertEq(exchangeUahCoinLiquidityAfter, exchangeUahCoinLiquidityBefore + buyRequest.minAmountOut);
  }

  function test_fulfillBuyRequest_makeRefund_whenUahAmountIsLessThenMinAmountOut()
    public
    withMockExchangeToken
    withMint(UAH_COIN_EXCHANGE_BALANCE)
    withExchangeBalance
    withExchangeTokenApprove
  {
    uint256 usdToUahExpectedExchangeRate = 40 * 1e18; // 1 USD = 40 UAH
    uint256 usdToUahActualExchangeRate = 39 * 1e18; // 1 USD = 50 UAH
    uint256 tokenAmount = BUYER_EXCHANGE_TOKEN_BALANCE;
    uint256 minAmountOut =
      exchange.estimateBuyAmountOut(address(exchangeToken), tokenAmount, usdToUahExpectedExchangeRate);

    vm.prank(BUYER);
    bytes32 requestId = exchange.makeBuyWithAmountInRequest(address(exchangeToken), tokenAmount, BUYER, minAmountOut);

    TypesLib.BuyRequest memory buyRequest = exchange.getBuyRequest(requestId);

    uint256 exchangeExchangeTokenBalanceBefore = exchangeToken.balanceOf(address(exchange));
    uint256 buyerExchangeTokenBalanceBefore = exchangeToken.balanceOf(BUYER);
    uint256 exchangeUahCoinLiquidityBefore = exchange.getUahCoinLiquidity();
    vm.prank(address(functionsRouterMock));
    exchange.handleOracleFulfillment(requestId, abi.encode(usdToUahActualExchangeRate), "");

    uint256 exchangeExchangeTokenBalanceAfter = exchangeToken.balanceOf(address(exchange));
    uint256 buyerExchangeTokenBalanceAfter = exchangeToken.balanceOf(BUYER);
    uint256 exchangeUahCoinLiquidityAfter = exchange.getUahCoinLiquidity();

    assertEq(exchangeExchangeTokenBalanceAfter, exchangeExchangeTokenBalanceBefore - buyRequest.tokenAmount);
    assertEq(buyerExchangeTokenBalanceAfter, buyerExchangeTokenBalanceBefore + buyRequest.tokenAmount);
    assertEq(exchangeUahCoinLiquidityAfter, exchangeUahCoinLiquidityBefore + buyRequest.minAmountOut);
  }

  /*//////////////////////////////////////////////////////////////
                              HELPERS
  //////////////////////////////////////////////////////////////*/

  modifier withMockExchangeToken() {
    exchangeTokenUSDRateOracle.updateAnswer(int256(EXCHANGE_TOKEN_USD_RATE));
    vm.prank(EXCHANGE_OWNER);
    exchange.addNewExchangeToken(address(exchangeToken), address(exchangeTokenUSDRateOracle));
    _;
  }

  modifier withExchangeBalance() {
    vm.prank(UAH_COIN_OWNER);
    uahCoin.withdraw(address(exchange), UAH_COIN_EXCHANGE_BALANCE);
    _;
  }

  modifier withExchangeTokenApprove() {
    exchangeToken.mint(BUYER, BUYER_EXCHANGE_TOKEN_BALANCE);
    vm.prank(BUYER);
    exchangeToken.approve(address(exchange), BUYER_EXCHANGE_TOKEN_BALANCE);
    _;
  }
}
