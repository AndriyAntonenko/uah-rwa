// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { DevOpsTools } from "foundry-devops/DevOpsTools.sol";

import { IUahCoin } from "../src/interfaces/IUahCoin.sol";
import { UahCoinNativeExchange } from "../src/exchange/UahCoinNativeExchange.sol";

contract DeployExchange is Script {
  error DeployExchange__UahCoinNotDeployed();

  function run() public {
    address uahCoin = DevOpsTools.get_most_recent_deployment("UahCoin", block.chainid);

    if (uahCoin == address(0)) {
      revert DeployExchange__UahCoinNotDeployed();
    }

    address exchangeOwner = vm.envAddress("EXCHANGE_OWNER");
    address functionRouter = vm.envAddress("EXCHANGE_CHAINLINK_FUNCTION_ROUTER");
    uint256 subscriptionId = vm.envUint("EXCHANGE_CHAINLINK_SUBSCRIPTION_ID");
    bytes32 donId = vm.envBytes32("EXCHANGE_CHAINLINK_DON_ID");
    string memory getUsdExcahngeRateSourceCode = vm.readFile("functions/sources/get-usd-exchange-rate.mjs");
    uint256 secretSlotId = vm.envUint("EXCHANGE_CHAINLINK_SECRET_SLOT_ID");
    uint256 secretsVersion = vm.envUint("EXCHANGE_CHAINLINK_SECRETS_VERSION");
    uint256 minimumBuyAmount = vm.envUint("EXCHANGE_MINIMUM_BUY_AMOUNT");

    vm.startBroadcast();
    deploy(
      exchangeOwner,
      uahCoin,
      minimumBuyAmount,
      functionRouter,
      uint64(subscriptionId),
      donId,
      getUsdExcahngeRateSourceCode,
      uint8(secretSlotId),
      uint64(secretsVersion)
    );
    vm.stopBroadcast();
  }

  function deploy(
    address _confirmedOwner,
    address _uahCoin,
    uint256 _minimumBuyAmount,
    address _functionRouter,
    uint64 _subscriptionId,
    bytes32 _donId,
    string memory _getUsdExcahngeRateSourceCode,
    uint8 _secretsSlotId,
    uint64 _secretsVersion
  )
    public
    returns (UahCoinNativeExchange)
  {
    return new UahCoinNativeExchange(
      _confirmedOwner,
      IUahCoin(_uahCoin),
      _minimumBuyAmount,
      _functionRouter,
      _subscriptionId,
      _donId,
      _getUsdExcahngeRateSourceCode,
      _secretsSlotId,
      _secretsVersion
    );
  }
}
