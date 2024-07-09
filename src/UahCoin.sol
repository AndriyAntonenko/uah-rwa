// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ConfirmedOwner } from "@chainlink/contracts/shared/access/ConfirmedOwner.sol";
import { FunctionsClient } from "@chainlink/contracts/functions/dev/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IUahCoin } from "./interfaces/IUahCoin.sol";
import { TypesLib } from "./libraries/TypesLib.sol";

contract UahCoin is ERC20, IUahCoin, ConfirmedOwner, FunctionsClient {
  using FunctionsRequest for FunctionsRequest.Request;

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  error UahCoin__HealthFactorTooLow(bytes32 mintRequestId);
  error UahCoin__FunctionError(bytes errorMessage);
  error UahCoin__InvalidRequestId(bytes32 requestId);
  error UahCoin__OnlyConfirmedValidator();

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /*
  * The stablecoin MUST be overcollateralized at all times. The health factor is responsible for this.
  * Ex: If the health factor is 200%, the stablecoin is overcollateralized by 2x. (Like 200% collateralization)
  */
  uint256 public constant HEALTH_FACTOR_PRECISION = 1e18;
  uint256 public constant HEALTH_FACTOR_RATIO = 150 * HEALTH_FACTOR_PRECISION;

  uint32 public constant FUNCTION_CALLBACK_GAS_LIMIT = 300_000;

  uint64 public immutable i_subscriptionId;
  bytes32 public immutable i_donId;
  address public immutable i_healthFactorValidator;

  /*//////////////////////////////////////////////////////////////
                                STATE
  //////////////////////////////////////////////////////////////*/

  address public s_confirmedValidator;
  string public s_getOffChainCollateralSourceCode;
  uint8 private s_secretsSlotId;
  uint64 private s_secretsVersion;
  TypesLib.HealthFactor private s_healthFactor;
  mapping(bytes32 => TypesLib.MintRequest) private s_mintRequests;

  constructor(
    address _confirmedOwner,
    address _functionRouter,
    uint64 _subscriptionId,
    bytes32 _donId,
    string memory _getOffChainCollateralSourceCode,
    uint8 _secretsSlotId,
    uint64 _secretsVersion,
    address _healthFactorValidator
  )
    ConfirmedOwner(_confirmedOwner)
    FunctionsClient(_functionRouter)
    ERC20("UahCoin", "UAHc")
  {
    i_subscriptionId = _subscriptionId;
    i_donId = _donId;
    i_healthFactorValidator = _healthFactorValidator;
    s_getOffChainCollateralSourceCode = _getOffChainCollateralSourceCode;
    s_secretsSlotId = _secretsSlotId;
    s_secretsVersion = _secretsVersion;
  }

  /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IUahCoin
  function sendMintRequest(uint256 _amount) external onlyOwner returns (bytes32 requestId) {
    FunctionsRequest.Request memory req;
    req.addDONHostedSecrets(s_secretsSlotId, s_secretsVersion);
    req.initializeRequestForInlineJavaScript(s_getOffChainCollateralSourceCode);

    bytes32 reqId = _sendRequest(req.encodeCBOR(), i_subscriptionId, FUNCTION_CALLBACK_GAS_LIMIT, i_donId);
    s_mintRequests[reqId] = TypesLib.MintRequest({ amount: _amount, requester: msg.sender });
    return reqId;
  }

  /// @inheritdoc IUahCoin
  function validateHealthFactor(uint256 _approvedOffChainCollateral)
    external
    returns (bool isHealthy, TypesLib.HealthFactor memory healthFactor)
  {
    if (msg.sender != i_healthFactorValidator) revert UahCoin__OnlyConfirmedValidator();

    healthFactor = _calculateHealthFactor(totalSupply(), _approvedOffChainCollateral);
    isHealthy = s_healthFactor.value >= HEALTH_FACTOR_RATIO;
    s_healthFactor = healthFactor;

    emit HealthFactorUpdated(s_healthFactor.value >= HEALTH_FACTOR_RATIO, s_healthFactor.value);
  }

  /// @param _requestId The ID of the Chainlink Functions request
  /// @return mintRequest The mint request
  function getMintRequest(bytes32 _requestId) external view returns (TypesLib.MintRequest memory) {
    return s_mintRequests[_requestId];
  }

  /// @notice Returns latest the health factor result
  /// @return healthFactor The health factor
  function getHealthFactor() external view returns (TypesLib.HealthFactor memory) {
    return s_healthFactor;
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
    if (_err.length > 0) revert UahCoin__FunctionError(_err);

    _fulfillMintRequest(_requestId, _response);
  }

  function _fulfillMintRequest(bytes32 _requestId, bytes memory _response) internal {
    uint256 accountBalance = _decodeMintFunctionResponse(_response);
    TypesLib.MintRequest memory mintRequest = s_mintRequests[_requestId];
    if (mintRequest.amount == 0) revert UahCoin__InvalidRequestId(_requestId);

    TypesLib.HealthFactor memory newHealthFactor =
      _calculateHealthFactorWithAdjustedAmount(mintRequest.amount, accountBalance);

    if (newHealthFactor.value < HEALTH_FACTOR_RATIO) revert UahCoin__HealthFactorTooLow(_requestId);
    s_healthFactor = newHealthFactor;
    _mint(address(this), mintRequest.amount);
  }

  function _decodeMintFunctionResponse(bytes memory _response) internal pure returns (uint256) {
    return abi.decode(_response, (uint256));
  }

  function _calculateHealthFactorWithAdjustedAmount(
    uint256 _adjustedAmount,
    uint256 _accountBalance
  )
    internal
    view
    returns (TypesLib.HealthFactor memory)
  {
    uint256 totalSupply = totalSupply();
    return _calculateHealthFactor(totalSupply + _adjustedAmount, _accountBalance);
  }

  function _calculateHealthFactor(
    uint256 _totalSupply,
    uint256 _totalCollateral
  )
    internal
    view
    returns (TypesLib.HealthFactor memory)
  {
    uint256 value = _totalCollateral * HEALTH_FACTOR_PRECISION / _totalSupply;

    return TypesLib.HealthFactor({
      value: value,
      totalSupply: _totalSupply,
      totalCollateral: _totalCollateral,
      lastUpdated: uint64(block.timestamp)
    });
  }
}
