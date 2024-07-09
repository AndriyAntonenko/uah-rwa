// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IUahCoinHealthFactorValidator } from "../src/interfaces/IUahCoinHealthFactorValidator.sol";
import { IUahCoin } from "../src/interfaces/IUahCoin.sol";

import { UahCoinHealthFactorValidator } from "../src/UahCoinHealthFactorValidator.sol";
import { UahCoinBaseTest } from "./base/UahCoinBase.t.sol";

contract UahCoinHealthFactorValidatorTest is UahCoinBaseTest {
  function test_sendValidationRequest_successful() public {
    vm.startPrank(UAH_COIN_VALIDATOR);
    vm.expectEmit(true, true, false, false);
    emit IUahCoinHealthFactorValidator.ValidationRequestSent(
      functionsRouterMock.s_nextMockedRequestId(), UAH_COIN_VALIDATOR
    );
    bytes32 requestId = uahCoinHealthFactorValidator.sendValidationRequest();
    vm.stopPrank();

    assertEq(uahCoinHealthFactorValidator.s_validationRequests(requestId), UAH_COIN_VALIDATOR);
    assertEq(uahCoinHealthFactorValidator.s_lastValidation(UAH_COIN_VALIDATOR), block.timestamp);
  }

  function test_sendValidationRequest_reverts_whenValidationIntervalNotPassed() public {
    test_sendValidationRequest_successful();

    uint256 newBlockTimestamp = uahCoinHealthFactorValidator.s_lastValidation(UAH_COIN_VALIDATOR)
      + uahCoinHealthFactorValidator.s_validationInterval() - 1;

    vm.warp(newBlockTimestamp);
    vm.startPrank(UAH_COIN_VALIDATOR);
    vm.expectRevert(
      abi.encodeWithSelector(
        UahCoinHealthFactorValidator.UahCoinHealthFactorValidator__ValidationRateLimitExceeded.selector,
        UAH_COIN_VALIDATOR
      )
    );
    uahCoinHealthFactorValidator.sendValidationRequest();
    vm.stopPrank();
  }

  function test_setValidationInterval_successfull() public {
    uint64 newValidationInterval = VALIDATION_INTERVAL * 2;

    vm.expectEmit(true, true, false, false);
    emit IUahCoinHealthFactorValidator.ValidationIntervalHasBeenChanged(newValidationInterval);
    vm.prank(UAH_COIN_HEALTH_FACTOR_VALIDATOR_OWNER);
    uahCoinHealthFactorValidator.setValidationInterval(newValidationInterval);

    assertEq(uahCoinHealthFactorValidator.s_validationInterval(), newValidationInterval);
  }

  function test_setValidationInterval_reverts_whenNotOwner() public {
    address notOwner = makeAddr("NOT_OWNER");
    vm.prank(notOwner);
    vm.expectRevert("Only callable by owner");
    uahCoinHealthFactorValidator.setValidationInterval(VALIDATION_INTERVAL);
  }

  function test_fulfillValidationRequest_successful() public withMint(defaultMintAmount) {
    vm.prank(UAH_COIN_VALIDATOR);
    bytes32 requestId = uahCoinHealthFactorValidator.sendValidationRequest();

    uint256 accountUahBalance =
      (defaultMintAmount * uahCoin.HEALTH_FACTOR_RATIO() / uahCoin.HEALTH_FACTOR_PRECISION()) / 2;
    bytes memory response = abi.encodePacked(accountUahBalance);
    bytes memory err = "";

    vm.startPrank(address(functionsRouterMock));
    vm.expectEmit(true, true, false, false);
    emit IUahCoin.HealthFactorUpdated(false, uahCoin.HEALTH_FACTOR_RATIO() / 2);
    uahCoinHealthFactorValidator.handleOracleFulfillment(requestId, response, err);
    vm.stopPrank();
  }

  function test_fulfillValidationRequest_reverts_whenInvalidRequestId() public withMint(defaultMintAmount) {
    bytes32 requestId = bytes32(uint256(1_234_567_890));
    uint256 accountUahBalance = defaultMintAmount * uahCoin.HEALTH_FACTOR_RATIO() / uahCoin.HEALTH_FACTOR_PRECISION();
    bytes memory response = abi.encodePacked(accountUahBalance);
    bytes memory err = "";

    vm.startPrank(address(functionsRouterMock));
    vm.expectRevert(
      abi.encodeWithSelector(
        UahCoinHealthFactorValidator.UahCoinHealthFactorValidator__InvalidRequestId.selector, requestId
      )
    );
    uahCoinHealthFactorValidator.handleOracleFulfillment(requestId, response, err);
    vm.stopPrank();
  }

  function test_fulfillValidationRequest_reverts_whenFunctionErrorReturned() public withMint(defaultMintAmount) {
    vm.prank(UAH_COIN_VALIDATOR);
    bytes32 requestId = uahCoinHealthFactorValidator.sendValidationRequest();
    bytes memory response = "";
    bytes memory err = abi.encodePacked("Function error");

    vm.startPrank(address(functionsRouterMock));
    vm.expectRevert(
      abi.encodeWithSelector(UahCoinHealthFactorValidator.UahCoinHealthFactorValidator__FuctionError.selector, err)
    );
    uahCoinHealthFactorValidator.handleOracleFulfillment(requestId, response, err);
    vm.stopPrank();
  }
}
