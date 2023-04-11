// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "universal-bridge-lib/UniversalBridgeLib.sol";

import "./VeRecipient.sol";
import "./base/Structs.sol";
import "./interfaces/IVotingEscrow.sol";

/// @title VeBeacon
/// @author zefram.eth
/// @notice Broadcasts veToken balances to other chains
contract VeBeacon {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error VeBeacon__EpochIsZero();
    error VeBeacon__LeftoverEth();
    error VeBeacon__UserNotInitialized();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event BroadcastVeBalance(address indexed user, uint256 indexed chainId);

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    uint256 internal constant SLOPE_CHANGES_LENGTH = 8;
    uint256 internal constant DATA_LENGTH = 4 + 8 * 32 + 32 + SLOPE_CHANGES_LENGTH * 64; // 4b selector + 8 * 32b args + 32b array length + SLOPE_CHANGES_LENGTH * 64b array content

    /// -----------------------------------------------------------------------
    /// Immutable params
    /// -----------------------------------------------------------------------

    IVotingEscrow public immutable votingEscrow;
    address public immutable recipientAddress;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(IVotingEscrow votingEscrow_, address recipientAddress_) {
        votingEscrow = votingEscrow_;
        recipientAddress = recipientAddress_;
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    /// @notice Broadcasts a user's vetoken balance to another chain. Should use getRequiredMessageValue()
    /// to compute the msg.value required when calling this function.
    /// @param user the user address
    /// @param chainId the target chain's ID
    /// @param gasLimit the gas limit of the call to the recipient
    /// @param maxFeePerGas the max gas price used, only relevant for some chains (e.g. Arbitrum)
    function broadcastVeBalance(address user, uint256 chainId, uint256 gasLimit, uint256 maxFeePerGas)
        external
        payable
    {
        _broadcastVeBalance(user, chainId, gasLimit, maxFeePerGas);
        if (address(this).balance != 0) revert VeBeacon__LeftoverEth();
    }

    /// @notice Broadcasts a user's vetoken balance to a list of other chains. Should use getRequiredMessageValue()
    /// to compute the msg.value required when calling this function (currently only applicable to Arbitrum).
    /// @param user the user address
    /// @param chainIdList the chain ID of the target chains
    /// @param gasLimit the gas limit of each call to the recipient
    /// @param maxFeePerGas the max gas price used, only relevant for some chains (e.g. Arbitrum)
    function broadcastVeBalanceMultiple(
        address user,
        uint256[] calldata chainIdList,
        uint256 gasLimit,
        uint256 maxFeePerGas
    ) external payable {
        uint256 chainIdListLength = chainIdList.length;
        for (uint256 i; i < chainIdListLength;) {
            _broadcastVeBalance(user, chainIdList[i], gasLimit, maxFeePerGas);

            unchecked {
                ++i;
            }
        }
        if (address(this).balance != 0) revert VeBeacon__LeftoverEth();
    }

    /// @notice Computes the msg.value needed when calling broadcastVeBalance(). Only relevant for Arbitrum.
    /// @param chainId the target chain's ID
    /// @param gasLimit the gas limit of the call to the recipient
    /// @param maxFeePerGas the max gas price used, only relevant for some chains (e.g. Arbitrum)
    /// @return the msg.value required
    function getRequiredMessageValue(uint256 chainId, uint256 gasLimit, uint256 maxFeePerGas)
        external
        view
        returns (uint256)
    {
        return UniversalBridgeLib.getRequiredMessageValue(chainId, DATA_LENGTH, gasLimit, maxFeePerGas);
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _constructBroadcastVeBalanceCalldata(address user) internal view returns (bytes memory data) {
        // get user voting escrow data
        uint256 epoch = votingEscrow.user_point_epoch(user);
        if (epoch == 0) revert VeBeacon__UserNotInitialized();
        (int128 userBias, int128 userSlope, uint256 userTs,) = votingEscrow.user_point_history(user, epoch);

        // get global data
        epoch = votingEscrow.epoch();
        if (epoch == 0) revert VeBeacon__EpochIsZero();
        (int128 globalBias, int128 globalSlope, uint256 globalTs,) = votingEscrow.point_history(epoch);

        // fetch slope changes in the range [currentEpochStartTimestamp + 1 weeks, currentEpochStartTimestamp + (SLOPE_CHANGES_LENGTH + 1) * 1 weeks]
        uint256 currentEpochStartTimestamp = (block.timestamp / (1 weeks)) * (1 weeks);
        SlopeChange[] memory slopeChanges = new SlopeChange[](SLOPE_CHANGES_LENGTH);
        for (uint256 i; i < SLOPE_CHANGES_LENGTH;) {
            currentEpochStartTimestamp += 1 weeks;
            slopeChanges[i] = SlopeChange({
                ts: currentEpochStartTimestamp,
                change: votingEscrow.slope_changes(currentEpochStartTimestamp)
            });
            unchecked {
                ++i;
            }
        }

        // send data to recipient on target chain using UniversalBridgeLib
        data = abi.encodeWithSelector(
            VeRecipient.updateVeBalance.selector,
            user,
            userBias,
            userSlope,
            userTs,
            globalBias,
            globalSlope,
            globalTs,
            slopeChanges
        );
    }

    function _broadcastVeBalance(address user, uint256 chainId, uint256 gasLimit, uint256 maxFeePerGas)
        internal
        virtual
    {
        bytes memory data = _constructBroadcastVeBalanceCalldata(user);

        uint256 requiredValue = UniversalBridgeLib.getRequiredMessageValue(chainId, DATA_LENGTH, gasLimit, maxFeePerGas);
        UniversalBridgeLib.sendMessage(chainId, recipientAddress, data, gasLimit, requiredValue, maxFeePerGas);

        emit BroadcastVeBalance(user, chainId);
    }
}
