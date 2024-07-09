// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library TypesLib {
  /*//////////////////////////////////////////////////////////////
                                TYPES
  //////////////////////////////////////////////////////////////*/

  struct MintRequest {
    uint256 amount;
    address requester;
  }

  struct HealthFactor {
    uint256 value;
    uint256 totalSupply;
    uint256 totalCollateral;
    uint64 lastUpdated;
  }
}
