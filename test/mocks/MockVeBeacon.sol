// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "../../src/VeBeacon.sol";

contract MockVeBeacon is VeBeacon {
    constructor(IVotingEscrow votingEscrow_, address recipientAddress_) VeBeacon(votingEscrow_, recipientAddress_) {}

    function _broadcastVeBalance(address user, uint256 chainId, uint256, uint256) internal override {
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
        bytes memory data = abi.encodeWithSelector(
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

        // replace bridge call with regular call for testing purposes
        (bool success,) = recipientAddress.call(data);
        require(success);

        emit BroadcastVeBalance(user, chainId);
    }
}
