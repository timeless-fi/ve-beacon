// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

/// @title VeRecipient
/// @author zefram.eth
/// @notice Recipient on non-Ethereum networks that receives data from the Ethereum beacon
/// and makes vetoken balances available on this network.
abstract contract VeRecipient {
    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    struct UserData {
        int128 bias;
        int128 slope;
        uint256 ts;
        uint256 delegated;
        uint256 received;
        uint256 expiryData;
    }

    struct GlobalData {
        int128 bias;
        int128 slope;
        uint256 ts;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error VeRecipient__InvalidBeacon();

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    address public beacon;
    mapping(address => UserData) public userData;
    GlobalData public globalData;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address beacon_) {
        beacon = beacon_;
    }

    /// -----------------------------------------------------------------------
    /// Crosschain functions
    /// -----------------------------------------------------------------------

    function updateVeBalance(
        address user,
        int128 userBias,
        int128 userSlope,
        uint256 userTs,
        uint256 delegated,
        uint256 received,
        uint256 expiryData,
        int128 globalBias,
        int128 globalSlope,
        uint256 globalTs
    ) external {
        _onlyBeacon();

        userData[user] = UserData({
            bias: userBias,
            slope: userSlope,
            ts: userTs,
            delegated: delegated,
            received: received,
            expiryData: expiryData
        });
        globalData = GlobalData({bias: globalBias, slope: globalSlope, ts: globalTs});
    }

    function setBeacon(address newBeacon) external {
        _onlyOwner();
        if (newBeacon == address(0)) revert VeRecipient__InvalidBeacon();
        beacon = newBeacon;
    }

    /// -----------------------------------------------------------------------
    /// View functions
    /// -----------------------------------------------------------------------

    function balanceOf(address user) external view returns (uint256) {}

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _onlyBeacon() internal virtual;

    function _onlyOwner() internal virtual;
}
