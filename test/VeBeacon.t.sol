// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CREATE3Factory} from "create3-factory/src/CREATE3Factory.sol";

import "forge-std/Test.sol";

import "solmate/tokens/ERC20.sol";

import "./mocks/MockVeBeacon.sol";
import "./mocks/MockVeRecipient.sol";
import "./interfaces/ISmartWalletChecker.sol";

contract VeBeaconTest is Test {
    CREATE3Factory constant create3 = CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
    IVotingEscrow constant votingEscrow = IVotingEscrow(0xf17d23136B4FeAd139f54fB766c8795faae09660);
    ISmartWalletChecker constant smartWalletChecker = ISmartWalletChecker(0x0CCdf95bAF116eDE5251223Ca545D0ED02287a8f);
    uint256 constant SLOPE_CHANGES_LENGTH = 8;
    string constant version = "1.0.0";

    MockVeBeacon beacon;
    MockVeRecipient recipient;

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

    function test_basicLock(uint256 waitTime) public {
        waitTime = bound(waitTime, 0, SLOPE_CHANGES_LENGTH * 1 weeks);

        // mint token
        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());
        deal(address(token), address(this), amount);

        // lock for vetoken for 1 year
        token.approve(address(votingEscrow), amount);
        uint256 lockTime = 365 days;
        votingEscrow.create_lock(amount, block.timestamp + lockTime);

        // push balance to recipient
        beacon.broadcastVeBalance(address(this), 0, 0, 0);

        // check balances
        assertEqDecimal(
            recipient.balanceOf(address(this)), votingEscrow.balanceOf(address(this)), 18, "balances not equal"
        );

        // check total supplies
        assertEqDecimal(recipient.totalSupply(), votingEscrow.totalSupply(), 18, "supplies not equal");

        // wait for some time
        skip(waitTime);

        // check balances
        assertEqDecimal(
            recipient.balanceOf(address(this)), votingEscrow.balanceOf(address(this)), 18, "later balances not equal"
        );

        // check total supplies
        assertEqDecimal(recipient.totalSupply(), votingEscrow.totalSupply(), 18, "later supplies not equal");
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
