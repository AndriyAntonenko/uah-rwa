// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IFunctionsRouter } from "@chainlink/contracts/functions/dev/v1_0_0/interfaces/IFunctionsRouter.sol";
import { FunctionsResponse } from "@chainlink/contracts/functions/dev/v1_0_0/libraries/FunctionsResponse.sol";

/// @title FunctionsRouterMock
/// @notice Mocks the FunctionsRouter contract, used for testing, return dummy values
contract FunctionsRouterMock is IFunctionsRouter {
  error FunctionsRouterMock__NotImplemented();

  bytes32 public s_nextMockedRequestId;

  constructor() {
    s_nextMockedRequestId = bytes32(uint256(1));
  }

  function sendRequest(uint64, bytes memory, uint16, uint32, bytes32) external returns (bytes32 requestId) {
    requestId = s_nextMockedRequestId;
    s_nextMockedRequestId = bytes32(uint256(s_nextMockedRequestId) + 1);
  }

  function getAllowListId() external pure returns (bytes32) {
    revert FunctionsRouterMock__NotImplemented();
  }

  function setAllowListId(bytes32) external pure {
    revert FunctionsRouterMock__NotImplemented();
  }

  function getAdminFee() external pure returns (uint72) {
    revert FunctionsRouterMock__NotImplemented();
  }

  function sendRequestToProposed(uint64, bytes calldata, uint16, uint32, bytes32) external pure returns (bytes32) {
    revert FunctionsRouterMock__NotImplemented();
  }

  function fulfill(
    bytes memory,
    bytes memory,
    uint96,
    uint96,
    address,
    FunctionsResponse.Commitment memory
  )
    external
    pure
    returns (FunctionsResponse.FulfillResult, uint96)
  {
    revert FunctionsRouterMock__NotImplemented();
  }

  function isValidCallbackGasLimit(uint64, uint32) external pure {
    revert FunctionsRouterMock__NotImplemented();
  }

  function getContractById(bytes32) external pure returns (address) {
    revert FunctionsRouterMock__NotImplemented();
  }

  function getProposedContractById(bytes32) external pure returns (address) {
    revert FunctionsRouterMock__NotImplemented();
  }

  function getProposedContractSet() external pure returns (bytes32[] memory, address[] memory) {
    revert FunctionsRouterMock__NotImplemented();
  }

  function proposeContractsUpdate(bytes32[] memory, address[] memory) external pure {
    revert FunctionsRouterMock__NotImplemented();
  }

  function updateContracts() external pure {
    revert FunctionsRouterMock__NotImplemented();
  }

  function pause() external pure {
    revert FunctionsRouterMock__NotImplemented();
  }

  function unpause() external pure {
    revert FunctionsRouterMock__NotImplemented();
  }
}
