// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {VeRecipient} from "../../src/VeRecipient.sol";

contract MockVeRecipient is VeRecipient {
    bool internal isCrossChain;

    constructor(address beacon_, address owner_) VeRecipient(beacon_, owner_) {
        isCrossChain = true;
    }

    function setIsCrossChain(bool value) external {
        isCrossChain = value;
    }

    /**
     * @dev Returns whether the current function call is the result of a
     * cross-chain message.
     */
    function _isCrossChain() internal view override returns (bool) {
        return isCrossChain;
    }

    /**
     * @dev Returns the address of the sender of the cross-chain message that
     * triggered the current function call.
     *
     * IMPORTANT: Should revert with `NotCrossChainCall` if the current function
     * call is not the result of a cross-chain message.
     */
    function _crossChainSender() internal view override onlyCrossChain returns (address) {
        return msg.sender;
    }
}
