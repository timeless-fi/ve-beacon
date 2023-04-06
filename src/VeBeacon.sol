// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "universal-bridge-lib/UniversalBridgeLib.sol";

import "./VeRecipient.sol";
import "./base/Structs.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IVotingEscrowDelegation.sol";

/// @title VeBeacon
/// @author zefram.eth
/// @notice Broadcasts veToken balances to other chains
contract VeBeacon {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error VeBeacon__EpochIsZero();
    error VeBeacon__UserNotInitialized();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event BroadcastVeBalance(address indexed user, uint256 indexed chainId);

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    uint256 internal constant MAX_SLOPE_CHANGES_LENGTH = 8;

    /// -----------------------------------------------------------------------
    /// Immutable params
    /// -----------------------------------------------------------------------

    IVotingEscrow public immutable votingEscrow;
    IVotingEscrowDelegation public immutable veDelegation;
    address public immutable recipientAddress;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    uint256 public lastSlopeChangeTimestamp;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(IVotingEscrow votingEscrow_, IVotingEscrowDelegation veDelegation_, address recipientAddress_) {
        votingEscrow = votingEscrow_;
        veDelegation = veDelegation_;
        recipientAddress = recipientAddress_;
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    function broadcastVeBalance(address user, uint256 chainId, uint256 gasLimit, uint256 maxFeePerGas)
        external
        payable
    {
        // get user voting escrow data
        uint256 epoch = votingEscrow.user_point_epoch(user);
        if (epoch == 0) revert VeBeacon__UserNotInitialized();
        (int128 userBias, int128 userSlope, uint256 userTs,) = votingEscrow.user_point_history(user, epoch);

        // get user ve delegation data
        (uint256 delegated, uint256 received, uint256 expiryData) = veDelegation.boost(user);

        // get global data
        epoch = votingEscrow.epoch();
        if (epoch == 0) revert VeBeacon__EpochIsZero();
        (int128 globalBias, int128 globalSlope, uint256 globalTs,) = votingEscrow.point_history(epoch);
        uint256 lastEpochStartTimestamp = (globalTs / (1 weeks)) * (1 weeks);
        SlopeChange[] memory slopeChanges;
        uint256 lastSlopeChangeTimestamp_ = lastSlopeChangeTimestamp;
        if (lastEpochStartTimestamp + (1 weeks) <= block.timestamp) {
            // there's a gap between the last voting escrow update and the current time
            // need to push slope_changes of the gap to the recipient

            // we can skip any of the slope changes between (lastEpochStartTimestamp + 1 weeks) and lastSlopeChangeTimestamp inclusive
            // since they've already been pushed to the recipient before
            if (lastEpochStartTimestamp + (1 weeks) <= lastSlopeChangeTimestamp_) {
                // the first epoch's slope change to push would be lastSlopeChangeTimestamp + 1 weeks
                lastEpochStartTimestamp = lastSlopeChangeTimestamp_;
            }

            uint256 slopeChangesLength = (block.timestamp - lastEpochStartTimestamp) / (1 weeks);
            if (slopeChangesLength != 0) {
                // limit the length of slopeChanges to prevent using up too much gas
                if (slopeChangesLength > MAX_SLOPE_CHANGES_LENGTH) slopeChangesLength = MAX_SLOPE_CHANGES_LENGTH;

                // fetch slope changes in the range [lastEpochStartTimestamp + 1 weeks, block.timestamp]
                slopeChanges = new SlopeChange[](slopeChangesLength);
                for (uint256 i; i < slopeChangesLength;) {
                    lastEpochStartTimestamp += 1 weeks;
                    slopeChanges[i] = SlopeChange({
                        ts: lastEpochStartTimestamp,
                        change: votingEscrow.slope_changes(lastEpochStartTimestamp)
                    });
                    unchecked {
                        ++i;
                    }
                }
                lastSlopeChangeTimestamp = lastEpochStartTimestamp;
            }
        }

        // send data to recipient on target chain using UniversalBridgeLib
        bytes memory data = abi.encodeWithSelector(
            VeRecipient.updateVeBalance.selector,
            user,
            userBias,
            userSlope,
            userTs,
            delegated,
            received,
            expiryData,
            globalBias,
            globalSlope,
            globalTs,
            slopeChanges
        );
        UniversalBridgeLib.sendMessage(chainId, recipientAddress, data, gasLimit, maxFeePerGas);

        emit BroadcastVeBalance(user, chainId);
    }
}
