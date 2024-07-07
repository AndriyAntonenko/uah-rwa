// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";

import { UahCoin } from "../src/UahCoin.sol";

contract Deploy is Script {
  function run() public {
    address owner = vm.envAddress("UAH_COIN_OWNER");
    address functionRouter = vm.envAddress("CHAINLINK_FUNCTION_ROUTER");
    uint256 subscriptionId = vm.envUint("CHAINLINK_SUBSCRIPTION_ID");
    bytes32 donId = vm.envBytes32("CHAINLINK_DON_ID");
    string memory getOffChainCollateralSourceCode = vm.readFile("functions/sources/get-off-chain-collateral.mjs");
    uint256 secretSlotId = vm.envUint("CHAINLINK_SECRET_SLOT_ID");
    uint256 secretsVersion = vm.envUint("CHAINLINK_SECRETS_VERSION");

    vm.startBroadcast();
    deployUahCoin(
      owner,
      functionRouter,
      uint64(subscriptionId),
      donId,
      getOffChainCollateralSourceCode,
      uint8(secretSlotId),
      uint64(secretsVersion)
    );
    vm.stopBroadcast();
  }

  function deployUahCoin(
    address _owner,
    address _functionRouter,
    uint64 _subscriptionId,
    bytes32 _donId,
    string memory _getOffChainCollateralSourceCode,
    uint8 _secretSlotId,
    uint64 _secretsVersion
  )
    public
    returns (UahCoin)
  {
    UahCoin uahCoin = new UahCoin(
      _owner, _functionRouter, _subscriptionId, _donId, _getOffChainCollateralSourceCode, _secretSlotId, _secretsVersion
    );

    return uahCoin;
  }
}
