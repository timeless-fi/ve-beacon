// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CrossChainEnabled} from "openzeppelin-contracts/contracts/crosschain/CrossChainEnabled.sol";

import "./base/Structs.sol";

/// @title VeRecipient
/// @author zefram.eth
/// @notice Recipient on non-Ethereum networks that receives data from the Ethereum beacon
/// and makes vetoken balances available on this network.
abstract contract VeRecipient is CrossChainEnabled {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error VeRecipient__InvalidInput();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event UpdateVeBalance(address indexed user);
    event SetBeacon(address indexed newBeacon);
    event TransferOwnership(address indexed newOwner);

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    uint256 internal constant MAX_ITERATIONS = 255;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    address public beacon;
    address public owner;
    mapping(address => Point) public userData;
    Point public globalData;
    mapping(uint256 => int128) public slopeChanges;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address beacon_, address owner_) {
        beacon = beacon_;
        owner = owner_;
    }

    /// -----------------------------------------------------------------------
    /// Crosschain functions
    /// -----------------------------------------------------------------------

    function updateVeBalance(
        address user,
        int128 userBias,
        int128 userSlope,
        uint256 userTs,
        int128 globalBias,
        int128 globalSlope,
        uint256 globalTs,
        SlopeChange[] calldata slopeChanges_
    ) external onlyCrossChainSender(beacon) {
        userData[user] = Point({bias: userBias, slope: userSlope, ts: userTs});
        globalData = Point({bias: globalBias, slope: globalSlope, ts: globalTs});

        uint256 slopeChangesLength = slopeChanges_.length;
        for (uint256 i; i < slopeChangesLength;) {
            slopeChanges[slopeChanges_[i].ts] = slopeChanges_[i].change;

            unchecked {
                ++i;
            }
        }

        emit UpdateVeBalance(user);
    }

    function setBeacon(address newBeacon) external onlyCrossChainSender(owner) {
        if (newBeacon == address(0)) revert VeRecipient__InvalidInput();
        beacon = newBeacon;
        emit SetBeacon(newBeacon);
    }

    function transferOwnership(address newOwner) external onlyCrossChainSender(owner) {
        if (newOwner == address(0)) revert VeRecipient__InvalidInput();
        owner = newOwner;
        emit TransferOwnership(newOwner);
    }

    /// -----------------------------------------------------------------------
    /// View functions
    /// -----------------------------------------------------------------------

    function balanceOf(address user) external view returns (uint256) {
        // storage loads
        Point memory u = userData[user];

        // compute vetoken balance
        int256 veBalance = u.bias - u.slope * int128(int256(block.timestamp - u.ts));
        if (veBalance < 0) veBalance = 0;
        return uint256(veBalance);
    }

    function totalSupply() external view returns (uint256) {
        Point memory g = globalData;
        uint256 ti = (g.ts / (1 weeks)) * (1 weeks);
        for (uint256 i; i < MAX_ITERATIONS;) {
            ti += 1 weeks;
            int128 slopeChange;
            if (ti > block.timestamp) {
                ti = block.timestamp;
            } else {
                slopeChange = slopeChanges[ti];
            }
            g.bias -= g.slope * int128(int256(ti - g.ts));
            if (ti == block.timestamp) break;
            g.slope += slopeChange;
            g.ts = ti;

            unchecked {
                ++i;
            }
        }

        if (g.bias < 0) g.bias = 0;
        return uint256(uint128(g.bias));
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _deconstructBiasSlope(uint256 data) internal pure returns (int128 bias, int128 slope) {
        bias = int128(int256(data >> 128)); // upper 128 bits
        slope = -int128(int256(data % (2 ** 128))); // negation of the lower 128 bits
    }

    function _abs(int256 x) internal pure returns (int256) {
        return x > 0 ? x : -x;
    }

    function _max(int256 x, int256 y) internal pure returns (int256) {
        return x > y ? x : y;
    }
}
