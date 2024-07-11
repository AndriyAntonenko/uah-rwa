// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UahCoin } from "../src/UahCoin.sol";
import { IUahCoin } from "../src/interfaces/IUahCoin.sol";
import { TypesLib } from "../src/libraries/TypesLib.sol";

import { UahCoinBaseTest } from "./base/UahCoinBase.t.sol";

contract UahCoinTest is UahCoinBaseTest {
  function test_setUp_successful() public view {
    assertEq(uahCoin.owner(), UAH_COIN_OWNER);
    assertEq(uahCoin.i_subscriptionId(), CHAINLINK_SUBSCRIPTION_ID);
    assertEq(uahCoin.i_donId(), CHAINLINK_DON_ID);
    assertEq(uahCoin.s_getOffChainCollateralSourceCode(), GET_OFF_CHAIN_COLLATERAL_SOURCE_CODE);
    assertEq(uahCoin.i_healthFactorValidator(), address(uahCoinHealthFactorValidator));
    assertEq(address(uahCoinHealthFactorValidator.i_uahCoin()), address(uahCoin));
  }

  function test_updateGetOffChainCollateralSourceCode_successful() public {
    string memory newSourceCode = "function getOffChainCollateralInfo() { return 2; }";
    vm.expectEmit(true, false, false, false);
    emit IUahCoin.GetOffChainCollateralSourceCodeUpdated();
    vm.prank(UAH_COIN_OWNER);
    uahCoin.updateGetOffChainCollateralSourceCode(newSourceCode);
    assertEq(uahCoin.s_getOffChainCollateralSourceCode(), newSourceCode);
  }

  function test_sendMintRequest_successful() public {
    uint256 amount = 100 * 10 ** uahCoin.decimals();

    vm.prank(UAH_COIN_OWNER);
    bytes32 requestId = uahCoin.sendMintRequest(amount);

    TypesLib.MintRequest memory mintRequest = uahCoin.getMintRequest(requestId);

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

    TypesLib.HealthFactor memory healthFactor = uahCoin.getHealthFactor();
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

  function test_withdraw_successful() public withMint(defaultMintAmount) {
    address to = makeAddr("to");

    vm.expectEmit(true, true, false, false);
    emit IUahCoin.Withdrawn(to, defaultMintAmount);
    vm.prank(UAH_COIN_OWNER);
    uahCoin.withdraw(to, defaultMintAmount);

    assertEq(uahCoin.balanceOf(to), defaultMintAmount);
    assertEq(uahCoin.balanceOf(address(uahCoin)), 0);
  }

  function test_secretsUpdate_successful() public {
    uint8 slotId = 13;
    uint64 version = 13;

    vm.expectEmit(true, true, false, false);
    emit IUahCoin.SecretsUpdated(slotId, version);
    vm.prank(UAH_COIN_OWNER);
    uahCoin.updateSecrets(slotId, version);

    assertEq(uahCoin.s_secretsSlotId(), slotId);
    assertEq(uahCoin.s_secretsVersion(), version);
  }
}
