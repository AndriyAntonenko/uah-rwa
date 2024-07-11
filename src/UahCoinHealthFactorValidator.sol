// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FunctionsClient } from "@chainlink/contracts/functions/dev/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import { ConfirmedOwner } from "@chainlink/contracts/shared/access/ConfirmedOwner.sol";

import { IUahCoin } from "./interfaces/IUahCoin.sol";
import { IUahCoinHealthFactorValidator } from "./interfaces/IUahCoinHealthFactorValidator.sol";

contract UahCoinHealthFactorValidator is ConfirmedOwner, FunctionsClient, IUahCoinHealthFactorValidator {
  using FunctionsRequest for FunctionsRequest.Request;

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  error UahCoinHealthFactorValidator__FuctionError(bytes errorMessage);
  error UahCoinHealthFactorValidator__InvalidRequestId(bytes32 requestId);
  error UahCoinHealthFactorValidator__ValidationRateLimitExceeded(address validator);

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  uint32 public constant FUNCTION_CALLBACK_GAS_LIMIT = 300_000;

  IUahCoin public immutable i_uahCoin;
  uint64 public immutable i_subscriptionId;
  bytes32 public immutable i_donId;

  /*//////////////////////////////////////////////////////////////
                                STATE
  //////////////////////////////////////////////////////////////*/

  string public s_getOffChainCollateralSourceCode;
  uint8 public s_secretsSlotId;
  uint64 public s_secretsVersion;
  uint64 public s_validationInterval;

  mapping(address validator => uint64 lastValidation) public s_lastValidation;
  mapping(bytes32 requestId => address validator) public s_validationRequests;

  constructor(
    IUahCoin _uahCoin,
    uint64 _validationInterval,
    address _confirmedOwner,
    address _functionRouter,
    uint64 _subscriptionId,
    bytes32 _donId,
    string memory _getOffChainCollateralSourceCode,
    uint8 _secretsSlotId,
    uint64 _secretsVersion
  )
    ConfirmedOwner(_confirmedOwner)
    FunctionsClient(_functionRouter)
  {
    i_uahCoin = _uahCoin;
    i_subscriptionId = _subscriptionId;
    i_donId = _donId;
    s_validationInterval = _validationInterval;
    s_getOffChainCollateralSourceCode = _getOffChainCollateralSourceCode;
    s_secretsSlotId = _secretsSlotId;
    s_secretsVersion = _secretsVersion;
  }

  /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IUahCoinHealthFactorValidator
  function updateSecrets(uint8 _slotId, uint64 _version) external {
    s_secretsSlotId = _slotId;
    s_secretsVersion = _version;
    emit SecretsUpdated(_slotId, _version);
  }

  /// @inheritdoc IUahCoinHealthFactorValidator
  function updateGetOffChainCollateralSourceCode(string memory _sourceCode) external onlyOwner {
    s_getOffChainCollateralSourceCode = _sourceCode;
    emit GetOffChainCollateralSourceCodeUpdated();
  }

  function setValidationInterval(uint64 _validationInterval) external onlyOwner {
    s_validationInterval = _validationInterval;
    emit ValidationIntervalHasBeenChanged(_validationInterval);
  }

  /// @inheritdoc IUahCoinHealthFactorValidator
  function sendValidationRequest() external returns (bytes32) {
    uint64 lastValidation = s_lastValidation[msg.sender];
    if (lastValidation != 0 && block.timestamp - lastValidation < s_validationInterval) {
      revert UahCoinHealthFactorValidator__ValidationRateLimitExceeded(msg.sender);
    }

    FunctionsRequest.Request memory req;
    req.addDONHostedSecrets(s_secretsSlotId, s_secretsVersion);
    req.initializeRequestForInlineJavaScript(s_getOffChainCollateralSourceCode);

    bytes32 reqId = _sendRequest(req.encodeCBOR(), i_subscriptionId, FUNCTION_CALLBACK_GAS_LIMIT, i_donId);
    s_validationRequests[reqId] = msg.sender;
    s_lastValidation[msg.sender] = uint64(block.timestamp);

    emit ValidationRequestSent(reqId, msg.sender);
    return reqId;
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
  function fulfillRequest(
    bytes32 _requestId,
    bytes memory _response,
    bytes memory _err
  )
    internal
    override(FunctionsClient)
  {
    if (_err.length > 0) {
      revert UahCoinHealthFactorValidator__FuctionError(_err);
    }

    _fulfillValidationRequest(_requestId, _response);
  }

  function _fulfillValidationRequest(bytes32 _requestId, bytes memory _response) internal {
    address validator = s_validationRequests[_requestId];
    if (validator == address(0)) {
      revert UahCoinHealthFactorValidator__InvalidRequestId(_requestId);
    }

    uint256 approvedOffChainCollateral = _decodeOffChainCollateralResponse(_response);
    i_uahCoin.validateHealthFactor(approvedOffChainCollateral);
  }

  function _decodeOffChainCollateralResponse(bytes memory _response) internal pure returns (uint256) {
    return abi.decode(_response, (uint256));
  }
}
