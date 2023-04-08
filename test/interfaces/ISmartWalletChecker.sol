// SPDX-License-Identifier: AGPL-.30
pragma solidity >=0.7.0 <0.9.0;

interface ISmartWalletChecker {
    function allowlistAddress(address contractAddress) external;
    function owner() external view returns (address);
}
