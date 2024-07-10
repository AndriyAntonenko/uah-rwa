// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";

import { UahCoin } from "../src/UahCoin.sol";
import { UahCoinHealthFactorValidator } from "../src/UahCoinHealthFactorValidator.sol";
import { IUahCoin } from "../src/interfaces/IUahCoin.sol";

contract Deploy is Script {
  function run() public {
    address uahCointOwner = vm.envAddress("UAH_COIN_OWNER");
    address uahCointHealthFactorValidatorOwner = vm.envAddress("UAH_COIN_HEALTH_FACTOR_VALIDATOR_OWNER");

    address functionRouter = vm.envAddress("CHAINLINK_FUNCTION_ROUTER");
    uint256 subscriptionId = vm.envUint("CHAINLINK_SUBSCRIPTION_ID");
    bytes32 donId = vm.envBytes32("CHAINLINK_DON_ID");
    string memory getOffChainCollateralSourceCode = vm.readFile("functions/sources/get-off-chain-collateral.mjs");
    uint256 secretSlotId = vm.envUint("CHAINLINK_SECRET_SLOT_ID");
    uint256 secretsVersion = vm.envUint("CHAINLINK_SECRETS_VERSION");
    uint256 validationInterval = vm.envUint("UAH_COIN_VALIDATION_INTERVAL");
    address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");

    vm.startBroadcast();
    deployUahCoin(
      uahCointOwner,
      uahCointHealthFactorValidatorOwner,
      uint64(validationInterval),
      functionRouter,
      uint64(subscriptionId),
      donId,
      getOffChainCollateralSourceCode,
      uint8(secretSlotId),
      uint64(secretsVersion),
      deployerAddress
    );
    vm.stopBroadcast();
  }

  function deployUahCoin(
    address _owner,
    address _uahCoinHealthFactorValidatorOwner,
    uint64 _validationInterval,
    address _functionRouter,
    uint64 _subscriptionId,
    bytes32 _donId,
    string memory _getOffChainCollateralSourceCode,
    uint8 _secretSlotId,
    uint64 _secretsVersion,
    address _deployerAddress
  )
    public
    returns (UahCoin, UahCoinHealthFactorValidator)
  {
    // If the deployer address is not set, use the current contract address. This is useful for testing.
    if (_deployerAddress == address(0)) {
      _deployerAddress = address(this);
    }

    uint64 nonce = vm.getNonce(_deployerAddress);
    address uahCoinAddress = vm.computeCreateAddress(_deployerAddress, nonce);
    address uahCoinHealthFactorValidatorAddress = vm.computeCreateAddress(_deployerAddress, nonce + 1);

    UahCoin uahCoin = new UahCoin(
      _owner,
      _functionRouter,
      _subscriptionId,
      _donId,
      _getOffChainCollateralSourceCode,
      _secretSlotId,
      _secretsVersion,
      uahCoinHealthFactorValidatorAddress
    );

    UahCoinHealthFactorValidator uahCoinHealthFactorValidator = new UahCoinHealthFactorValidator(
      IUahCoin(uahCoinAddress),
      _validationInterval,
      _uahCoinHealthFactorValidatorOwner,
      _functionRouter,
      _subscriptionId,
      _donId,
      _getOffChainCollateralSourceCode,
      _secretSlotId,
      _secretsVersion
    );

    return (uahCoin, uahCoinHealthFactorValidator);
  }
}
