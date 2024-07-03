// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ConfirmedOwner } from "@chainlink/contracts/shared/access/ConfirmedOwner.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UahCoin is ERC20, ConfirmedOwner {
  constructor(address _owner) ConfirmedOwner(_owner) ERC20("UahCoin", "UAHc") { }
}
