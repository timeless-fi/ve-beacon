// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "universal-bridge-lib/UniversalBridgeLib.sol";

import "./VeRecipient.sol";
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
    /// Immutable params
    /// -----------------------------------------------------------------------

    IVotingEscrow public immutable votingEscrow;
    IVotingEscrowDelegation public immutable veDelegation;
    address public immutable recipientAddress;

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
            globalTs
        );
        UniversalBridgeLib.sendMessage(chainId, recipientAddress, data, gasLimit, maxFeePerGas);
    }
}
