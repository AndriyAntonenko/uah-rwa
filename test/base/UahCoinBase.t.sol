// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { Deploy } from "../../script/Deploy.s.sol";
import { UahCoinHealthFactorValidator } from "../../src/UahCoinHealthFactorValidator.sol";
import { UahCoin } from "../../src/UahCoin.sol";
import { FunctionsRouterMock } from "../mocks/FunctionsRouterMock.sol";

contract UahCoinBaseTest is Test {
  address public immutable UAH_COIN_VALIDATOR = makeAddr("UAH_COIN_VALIDATOR");
  address public immutable UAH_COIN_OWNER = makeAddr("UAH_COIN_OWNER");
  address public immutable UAH_COIN_HEALTH_FACTOR_VALIDATOR_OWNER = makeAddr("UAH_COIN_HEALTH_FACTOR_VALIDATOR_OWNER");
  uint64 public immutable VALIDATION_INTERVAL = 10 minutes;

  uint64 public constant CHAINLINK_SUBSCRIPTION_ID = 1;
  bytes32 public constant CHAINLINK_DON_ID = bytes32(uint256(1));
  uint8 public constant CHAINLINK_SECRET_SLOT_ID = 1;
  uint64 public constant CHAINLINK_SECRETS_VERSION = 1;
  string public constant GET_OFF_CHAIN_COLLATERAL_SOURCE_CODE = "function getOffChainCollateralInfo() { return 1; }";

  uint256 public defaultMintAmount;
  FunctionsRouterMock public functionsRouterMock;
  UahCoin public uahCoin;
  UahCoinHealthFactorValidator public uahCoinHealthFactorValidator;

  function setUp() public virtual {
    Deploy deploy = new Deploy();

    functionsRouterMock = new FunctionsRouterMock();
    (uahCoin, uahCoinHealthFactorValidator) = deploy.deployUahCoin(
      UAH_COIN_OWNER,
      UAH_COIN_HEALTH_FACTOR_VALIDATOR_OWNER,
      VALIDATION_INTERVAL,
      address(functionsRouterMock),
      CHAINLINK_SUBSCRIPTION_ID,
      CHAINLINK_DON_ID,
      GET_OFF_CHAIN_COLLATERAL_SOURCE_CODE,
      CHAINLINK_SECRET_SLOT_ID,
      CHAINLINK_SECRETS_VERSION,
      address(0)
    );

    defaultMintAmount = 100 * 10 ** uahCoin.decimals();
  }

  modifier withMint(uint256 _amount) {
    uint256 totalSupplyBefore = uahCoin.totalSupply();

    vm.prank(UAH_COIN_OWNER);
    bytes32 requestId = uahCoin.sendMintRequest(_amount);

    uint256 accountUahBalance = _amount * uahCoin.HEALTH_FACTOR_RATIO() / uahCoin.HEALTH_FACTOR_PRECISION();
    bytes memory response = abi.encodePacked(accountUahBalance);
    bytes memory err = "";

    vm.prank(address(functionsRouterMock));
    uahCoin.handleOracleFulfillment(requestId, response, err);

    _;
  }
}
