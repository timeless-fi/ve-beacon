// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CrossChainEnabledOptimism} from
    "openzeppelin-contracts/contracts/crosschain/optimism/CrossChainEnabledOptimism.sol";

import {VeRecipient} from "../VeRecipient.sol";

contract VeRecipientOptimism is VeRecipient, CrossChainEnabledOptimism(0x4200000000000000000000000000000000000007) {
    constructor(address beacon_, address owner_) VeRecipient(beacon_, owner_) {}
}
