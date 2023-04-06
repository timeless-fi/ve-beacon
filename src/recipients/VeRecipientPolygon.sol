// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CrossChainEnabledPolygonChild} from
    "openzeppelin-contracts/contracts/crosschain/polygon/CrossChainEnabledPolygonChild.sol";

import {VeRecipient} from "../VeRecipient.sol";

contract VeRecipientPolygon is
    VeRecipient,
    CrossChainEnabledPolygonChild(0x8397259c983751DAf40400790063935a11afa28a)
{
    constructor(address beacon_, address owner_) VeRecipient(beacon_, owner_) {}
}
