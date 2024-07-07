// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IFunctionsRouter } from "@chainlink/contracts/functions/dev/v1_0_0/interfaces/IFunctionsRouter.sol";

import { UahCoin } from "../src/UahCoin.sol";
import { Deploy } from "../script/Deploy.s.sol";

import { FunctionsRouterMock } from "./mocks/FunctionsRouterMock.sol";

contract UahCoinTest is Test {
  address public immutable UAH_COIN_OWNER = makeAddr("UAH_COIN_OWNER");
  uint64 public constant CHAINLINK_SUBSCRIPTION_ID = 1;
  bytes32 public constant CHAINLINK_DON_ID = bytes32(uint256(1));
  uint8 public constant CHAINLINK_SECRET_SLOT_ID = 1;
  uint64 public constant CHAINLINK_SECRETS_VERSION = 1;
  string public constant GET_OFF_CHAIN_COLLATERAL_SOURCE_CODE = "function getOffChainCollateralInfo() { return 1; }";

  IFunctionsRouter public functionsRouterMock;
  UahCoin public uahCoin;

  function setUp() public {
    Deploy deploy = new Deploy();

    functionsRouterMock = IFunctionsRouter(address(new FunctionsRouterMock()));
    uahCoin = deploy.deployUahCoin(
      UAH_COIN_OWNER,
      address(functionsRouterMock),
      CHAINLINK_SUBSCRIPTION_ID,
      CHAINLINK_DON_ID,
      GET_OFF_CHAIN_COLLATERAL_SOURCE_CODE,
      CHAINLINK_SECRET_SLOT_ID,
      CHAINLINK_SECRETS_VERSION
    );
  }

  function test_setUp_successful() public view {
    assertEq(uahCoin.owner(), UAH_COIN_OWNER);
    assertEq(uahCoin.i_subscriptionId(), CHAINLINK_SUBSCRIPTION_ID);
    assertEq(uahCoin.i_donId(), CHAINLINK_DON_ID);
    assertEq(uahCoin.s_getOffChainCollateralSourceCode(), GET_OFF_CHAIN_COLLATERAL_SOURCE_CODE);
  }

  function test_sendMintRequest_successful() public {
    uint256 amount = 100 * 10 ** uahCoin.decimals();

    vm.prank(UAH_COIN_OWNER);
    bytes32 requestId = uahCoin.sendMintRequest(amount);

    UahCoin.MintRequest memory mintRequest = uahCoin.getMintRequest(requestId);

    assertEq(mintRequest.amount, amount);
    assertEq(mintRequest.requester, UAH_COIN_OWNER);
  }

  function test_fulfillMintRequest_successful() public {
    uint256 mintAmount = 100 * 10 ** uahCoin.decimals();
    uint256 totalSupplyBefore = uahCoin.totalSupply();

    vm.prank(UAH_COIN_OWNER);
    bytes32 requestId = uahCoin.sendMintRequest(mintAmount);

    uint256 accountUahBalance = mintAmount * uahCoin.HEALTH_FACTOR_RATIO() / uahCoin.HEALTH_FACTOR_PRECISION();
    bytes memory response = abi.encodePacked(accountUahBalance);
    bytes memory err = "";

    vm.prank(address(functionsRouterMock));
    uahCoin.handleOracleFulfillment(requestId, response, err);

    UahCoin.HealthFactor memory healthFactor = uahCoin.getHealthFactor();
    assertEq(uahCoin.totalSupply(), totalSupplyBefore + mintAmount);
    assertEq(uahCoin.balanceOf(address(uahCoin)), mintAmount);

    assert(healthFactor.value >= uahCoin.HEALTH_FACTOR_RATIO());
    assertEq(healthFactor.totalSupply, totalSupplyBefore + mintAmount);
    assertEq(healthFactor.totalCollateral, accountUahBalance);
    assertEq(healthFactor.lastUpdated, block.timestamp);
  }

  function test_fulfillMintRequestReverts_whenInvalidRequestId() public {
    bytes32 requestId = bytes32(uint256(1));
    uint256 mintAmount = 100 * 10 ** uahCoin.decimals();
    bytes memory response = abi.encodePacked(mintAmount);
    bytes memory err = "";

    vm.prank(address(functionsRouterMock));
    vm.expectRevert(abi.encodeWithSelector(UahCoin.UahCoin__InvalidRequestId.selector, requestId));
    uahCoin.handleOracleFulfillment(requestId, response, err);
  }

  function test_fulfillMintRequestReverts_whenFunctionErrorReturned() public {
    uint256 mintAmount = 100 * 10 ** uahCoin.decimals();
    vm.prank(UAH_COIN_OWNER);
    bytes32 requestId = uahCoin.sendMintRequest(mintAmount);
    bytes memory response = "";
    bytes memory err = abi.encodePacked("Function error");

    vm.prank(address(functionsRouterMock));
    vm.expectRevert(abi.encodeWithSelector(UahCoin.UahCoin__FunctionError.selector, err));
    uahCoin.handleOracleFulfillment(requestId, response, err);
  }

  function test_fulfillMintRequestReverts_whenHealthFactorTooLow() public {
    uint256 mintAmount = 100 * 10 ** uahCoin.decimals();
    uint256 offChainBalance = (mintAmount * uahCoin.HEALTH_FACTOR_RATIO() / uahCoin.HEALTH_FACTOR_PRECISION()) - 1;

    vm.prank(UAH_COIN_OWNER);
    bytes32 requestId = uahCoin.sendMintRequest(mintAmount);
    bytes memory response = abi.encodePacked(offChainBalance);
    bytes memory err = "";

    vm.prank(address(functionsRouterMock));
    vm.expectRevert(abi.encodeWithSelector(UahCoin.UahCoin__HealthFactorTooLow.selector, requestId));
    uahCoin.handleOracleFulfillment(requestId, response, err);
  }
}
