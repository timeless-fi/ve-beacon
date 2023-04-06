// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CrossChainEnabledAMB} from "openzeppelin-contracts/contracts/crosschain/amb/CrossChainEnabledAMB.sol";

import {VeRecipient} from "../VeRecipient.sol";

contract VeRecipientAMB is VeRecipient, CrossChainEnabledAMB {
    constructor(address beacon_, address owner_, address bridge_)
        VeRecipient(beacon_, owner_)
        CrossChainEnabledAMB(bridge_)
    {}
}
