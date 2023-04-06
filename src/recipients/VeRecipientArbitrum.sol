// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CrossChainEnabledArbitrumL2} from
    "openzeppelin-contracts/contracts/crosschain/arbitrum/CrossChainEnabledArbitrumL2.sol";

import {VeRecipient} from "../VeRecipient.sol";

contract VeRecipientArbitrum is VeRecipient, CrossChainEnabledArbitrumL2 {
    constructor(address beacon_, address owner_) VeRecipient(beacon_, owner_) {}
}
