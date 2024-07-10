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
      uint64(secretsVersion)
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
    uint64 _secretsVersion
  )
    public
    returns (UahCoin, UahCoinHealthFactorValidator)
  {
    uint64 nonce = vm.getNonce(address(this));
    address uahCoinAddress = _contractAddressFrom(address(this), nonce);
    address uahCoinHealthFactorValidatorAddress = _contractAddressFrom(address(this), nonce + 1);

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

  /// @dev Computes the address of a contract deployed by the given address and nonce (via CREATE opcode)
  /// @param deployer The address of the deployer
  /// @param nonce The nonce of the deployer
  /// @return The address of the contract
  function _contractAddressFrom(address deployer, uint256 nonce) private pure returns (address) {
    if (nonce == 0x00) {
      return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80))))));
    }
    if (nonce <= 0x7f) {
      return address(
        uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce))))))
      );
    }
    if (nonce <= 0xff) {
      return address(
        uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce)))))
      );
    }
    if (nonce <= 0xffff) {
      return address(
        uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce)))))
      );
    }
    if (nonce <= 0xffffff) {
      return address(
        uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce)))))
      );
    }
    return address(
      uint160(uint256(keccak256(abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce)))))
    );
  }
}
