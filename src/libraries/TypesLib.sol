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

  /*//////////////////////////////////////////////////////////////
                            EXCHANGE TYPES
  //////////////////////////////////////////////////////////////*/

  enum RequestType {
    Unknown, // aka default value, that should never be assigned, but could be used for checking if value is set
    BuyWithAmountIn,
    BuyWithAmountOut,
    SellWithAmountIn,
    SellWithAmountOut
  }

  struct ExchangeRequest {
    RequestType requestType;
    address exchangeToken;
    uint256 amount;
    address requester;
    uint256 limit;
  }
}
