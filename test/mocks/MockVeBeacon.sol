// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import "../../src/VeBeacon.sol";

contract MockVeBeacon is VeBeacon {
    constructor(IVotingEscrow votingEscrow_, address recipientAddress_) VeBeacon(votingEscrow_, recipientAddress_) {}

    function _broadcastVeBalance(address user, uint256 chainId, uint256, uint256) internal override {
        bytes memory data = _constructBroadcastVeBalanceCalldata(user);

        // replace bridge call with regular call for testing purposes
        (bool success,) = recipientAddress.call(data);
        require(success);

        emit BroadcastVeBalance(user, chainId);
    }
}
