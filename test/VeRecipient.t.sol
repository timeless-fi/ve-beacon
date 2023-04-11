// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CREATE3Factory} from "create3-factory/src/CREATE3Factory.sol";

import "forge-std/Test.sol";

import "solmate/tokens/ERC20.sol";

import "universal-bridge-lib/UniversalBridgeLib.sol";

import "./mocks/MockVeBeacon.sol";
import "./mocks/MockVeRecipient.sol";
import "./interfaces/ISmartWalletChecker.sol";

contract VeRecipientTest is Test {
    CREATE3Factory constant create3 = CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
    IVotingEscrow constant votingEscrow = IVotingEscrow(0xf17d23136B4FeAd139f54fB766c8795faae09660);
    ISmartWalletChecker constant smartWalletChecker = ISmartWalletChecker(0x0CCdf95bAF116eDE5251223Ca545D0ED02287a8f);
    string constant version = "1.0.0";

    MockVeBeacon beacon;
    MockVeRecipient recipient;

    error InvalidCrossChainSender(address actual, address expected);

    function setUp() public {
        beacon = MockVeBeacon(
            create3.deploy(
                getCreate3ContractSalt("MockVeBeacon"),
                bytes.concat(
                    type(MockVeBeacon).creationCode, abi.encode(votingEscrow, getCreate3Contract("MockVeRecipient"))
                )
            )
        );
        recipient = MockVeRecipient(
            create3.deploy(
                getCreate3ContractSalt("MockVeRecipient"),
                bytes.concat(
                    type(MockVeRecipient).creationCode, abi.encode(getCreate3Contract("MockVeBeacon"), address(this))
                )
            )
        );

        // whitelist test contract as locker
        address owner = smartWalletChecker.owner();
        vm.prank(owner);
        smartWalletChecker.allowlistAddress(address(this));
    }

    function test_setBeacon(address newBeacon) public {
        if (newBeacon == address(0)) {
            vm.expectRevert(VeRecipient.VeRecipient__InvalidInput.selector);
            recipient.setBeacon(newBeacon);
        } else {
            recipient.setBeacon(newBeacon);
            assertEq(recipient.beacon(), newBeacon, "didn't set new beacon");
        }
    }

    function test_transferOwnership(address newOwner) public {
        if (newOwner == address(0)) {
            vm.expectRevert(VeRecipient.VeRecipient__InvalidInput.selector);
            recipient.transferOwnership(newOwner);
        } else {
            recipient.transferOwnership(newOwner);
            assertEq(recipient.owner(), newOwner, "didn't set new owner");
        }
    }

    function test_fail_updateVeBalanceAsRando(
        address user,
        int128 userBias,
        int128 userSlope,
        uint256 userTs,
        int128 globalBias,
        int128 globalSlope,
        uint256 globalTs,
        SlopeChange[] calldata slopeChanges_
    ) public {
        address rando = address(0x69);
        vm.startPrank(rando);
        vm.expectRevert(abi.encodeWithSelector(InvalidCrossChainSender.selector, rando, beacon));
        recipient.updateVeBalance(user, userBias, userSlope, userTs, globalBias, globalSlope, globalTs, slopeChanges_);
        vm.stopPrank();
    }

    function test_fail_setBeaconAsRando(address newBeacon) public {
        address rando = address(0x69);
        if (newBeacon == address(0)) {
            vm.expectRevert(VeRecipient.VeRecipient__InvalidInput.selector);
            recipient.setBeacon(newBeacon);
        } else {
            vm.startPrank(rando);
            vm.expectRevert(abi.encodeWithSelector(InvalidCrossChainSender.selector, rando, address(this)));
            recipient.setBeacon(newBeacon);
            vm.stopPrank();
        }
    }

    function test_fail_transferOwnershipAsRando(address newOwner) public {
        address rando = address(0x69);
        if (newOwner == address(0)) {
            vm.expectRevert(VeRecipient.VeRecipient__InvalidInput.selector);
            recipient.transferOwnership(newOwner);
        } else {
            vm.startPrank(rando);
            vm.expectRevert(abi.encodeWithSelector(InvalidCrossChainSender.selector, rando, address(this)));
            recipient.transferOwnership(newOwner);
            vm.stopPrank();
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal helpers
    /// -----------------------------------------------------------------------

    function getCreate3Contract(string memory name) internal view virtual returns (address) {
        return create3.getDeployed(address(this), getCreate3ContractSalt(name));
    }

    function getCreate3ContractSalt(string memory name) internal view virtual returns (bytes32) {
        return keccak256(bytes(string.concat(name, "-v", version)));
    }
}
