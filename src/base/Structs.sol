// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

struct SlopeChange {
    uint256 ts;
    int128 change;
}

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
