// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CREATE3Factory} from "create3-factory/src/CREATE3Factory.sol";

import "forge-std/Test.sol";

import "solmate/tokens/ERC20.sol";

import "universal-bridge-lib/UniversalBridgeLib.sol";

import "./mocks/MockVeBeacon.sol";
import "./mocks/MockVeRecipient.sol";
import "./interfaces/ISmartWalletChecker.sol";

contract VeBeaconTest is Test {
    using stdStorage for StdStorage;

    CREATE3Factory constant create3 = CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
    IVotingEscrow constant votingEscrow = IVotingEscrow(0xf17d23136B4FeAd139f54fB766c8795faae09660);
    ISmartWalletChecker constant smartWalletChecker = ISmartWalletChecker(0x0CCdf95bAF116eDE5251223Ca545D0ED02287a8f);
    uint256 constant SLOPE_CHANGES_LENGTH = 8;
    string constant version = "1.0.0";

    MockVeBeacon beacon;
    VeBeacon prodBeacon;
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
        prodBeacon = VeBeacon(
            create3.deploy(
                getCreate3ContractSalt("VeBeacon"),
                bytes.concat(
                    type(VeBeacon).creationCode, abi.encode(votingEscrow, getCreate3Contract("MockVeRecipient"))
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

    function test_equivalence_basicLock(uint256 waitTime) public {
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

        _verifyEquivalence(waitTime);
    }

    function test_equivalence_multipleLocks(uint256 waitTime) external {
        uint256 numUsers = 10;
        waitTime = bound(waitTime, 0, SLOPE_CHANGES_LENGTH * 1 weeks);

        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());

        address[] memory users = new address[](numUsers);
        for (uint8 i; i < numUsers; i++) {
            address user = address(uint160(i + 0x69));

            // whitelist user as locker
            address owner = smartWalletChecker.owner();
            vm.prank(owner);
            smartWalletChecker.allowlistAddress(user);

            vm.startPrank(user);

            // mint token
            deal(address(token), user, amount);

            // lock for vetoken for 1 year
            token.approve(address(votingEscrow), amount);
            uint256 lockTime = 365 days;
            votingEscrow.create_lock(amount, block.timestamp + lockTime);

            // push balance to recipient
            beacon.broadcastVeBalance(user, 0, 0, 0);

            vm.stopPrank();

            users[i] = user;
        }

        _verifyEquivalence(waitTime, users);
    }

    function test_equivalence_lockMultipleTimes(uint256 waitTime) public {
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
        for (uint256 i; i < 10; i++) {
            beacon.broadcastVeBalance(address(this), 0, 0, 0);
        }

        _verifyEquivalence(waitTime);
    }

    function test_equivalence_broadcastMultiple_singleUser(uint256 waitTime) public {
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
        uint256[] memory chainIdList = new uint256[](10);
        beacon.broadcastVeBalanceMultiple(address(this), chainIdList, 0, 0);

        _verifyEquivalence(waitTime);
    }

    function test_equivalence_broadcastMultiple_multipleUsers(uint256 waitTime) external {
        uint256 numUsers = 10;
        waitTime = bound(waitTime, 0, SLOPE_CHANGES_LENGTH * 1 weeks);

        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());

        address[] memory users = new address[](numUsers);
        for (uint8 i; i < numUsers; i++) {
            address user = address(uint160(i + 0x69));

            // whitelist user as locker
            address owner = smartWalletChecker.owner();
            vm.prank(owner);
            smartWalletChecker.allowlistAddress(user);

            vm.startPrank(user);

            // mint token
            deal(address(token), user, amount);

            // lock for vetoken for 1 year
            token.approve(address(votingEscrow), amount);
            uint256 lockTime = 365 days;
            votingEscrow.create_lock(amount, block.timestamp + lockTime);

            vm.stopPrank();

            users[i] = user;
        }

        // push balance to recipient
        uint256[] memory chainIdList = new uint256[](10);
        beacon.broadcastVeBalanceMultiple(users, chainIdList, 0, 0);

        _verifyEquivalence(waitTime, users);
    }

    function test_getRequiredMessageValue() public {
        // mint token
        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());
        deal(address(token), address(this), amount);

        // lock for vetoken for 1 year
        token.approve(address(votingEscrow), amount);
        uint256 lockTime = 365 days;
        votingEscrow.create_lock(amount, block.timestamp + lockTime);

        // check message value for arbitrum
        uint256 gasLimit = 1e6;
        uint256 maxFeePerGas = 0.1 gwei;
        uint256 value = beacon.getRequiredMessageValue(UniversalBridgeLib.CHAINID_ARBITRUM, gasLimit, maxFeePerGas);
        uint256 dataLength = 4 + 8 * 32 + 32 + SLOPE_CHANGES_LENGTH * 64; // 4b selector + 8 * 32b args + 32b array length + SLOPE_CHANGES_LENGTH * 64b array content
        uint256 expectedValue = UniversalBridgeLib.getRequiredMessageValue(
            UniversalBridgeLib.CHAINID_ARBITRUM, dataLength, gasLimit, maxFeePerGas
        );
        assertEqDecimal(value, expectedValue, 18, "arbitrum message value doesn't match");

        // check message value for non-arbitrum network
        value = beacon.getRequiredMessageValue(UniversalBridgeLib.CHAINID_OPTIMISM, gasLimit, maxFeePerGas);
        expectedValue = UniversalBridgeLib.getRequiredMessageValue(
            UniversalBridgeLib.CHAINID_OPTIMISM, dataLength, gasLimit, maxFeePerGas
        );
        assertEqDecimal(value, expectedValue, 18, "non-arbitrum message value doesn't match");
    }

    function test_prodBeaconBroadcast() public {
        // mint token
        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());
        deal(address(token), address(this), amount);

        // lock for vetoken for 1 year
        token.approve(address(votingEscrow), amount);
        uint256 lockTime = 365 days;
        votingEscrow.create_lock(amount, block.timestamp + lockTime);

        // push balance to recipient
        uint256[] memory chainIdList = new uint256[](5);
        chainIdList[0] = UniversalBridgeLib.CHAINID_ARBITRUM;
        chainIdList[1] = UniversalBridgeLib.CHAINID_OPTIMISM;
        chainIdList[2] = UniversalBridgeLib.CHAINID_POLYGON;
        chainIdList[3] = UniversalBridgeLib.CHAINID_BSC;
        chainIdList[4] = UniversalBridgeLib.CHAINID_GNOSIS;
        uint256 gasLimit = 1e6;
        uint256 maxFeePerGas = 0.1 gwei;
        uint256 value = prodBeacon.getRequiredMessageValue(UniversalBridgeLib.CHAINID_ARBITRUM, gasLimit, maxFeePerGas);
        prodBeacon.broadcastVeBalanceMultiple{value: value}(address(this), chainIdList, gasLimit, maxFeePerGas);
    }

    function test_refund_broadcastVeBalance(uint256 extraValue) public {
        extraValue = bound(extraValue, 0, 1e18 ether);

        // deal ETH to this
        deal(address(this), address(this).balance + extraValue);

        // mint token
        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());
        deal(address(token), address(this), amount);

        // lock for vetoken for 1 year
        token.approve(address(votingEscrow), amount);
        uint256 lockTime = 365 days;
        votingEscrow.create_lock(amount, block.timestamp + lockTime);

        // push balance to recipient
        uint256 gasLimit = 1e6;
        uint256 maxFeePerGas = 0.1 gwei;
        uint256 value = prodBeacon.getRequiredMessageValue(UniversalBridgeLib.CHAINID_ARBITRUM, gasLimit, maxFeePerGas);
        uint256 beforeBalance = address(this).balance;
        prodBeacon.broadcastVeBalance{value: value + extraValue}(
            address(this), UniversalBridgeLib.CHAINID_ARBITRUM, gasLimit, maxFeePerGas
        );

        if (extraValue >= block.basefee * 21000) {
            assertEqDecimal(beforeBalance - address(this).balance, value, 18, "didn't get refund");
        }
    }

    function test_refund_broadcastVeBalanceMultiple(uint256 extraValue) public {
        extraValue = bound(extraValue, 0, 1e18 ether);

        // deal ETH to this
        deal(address(this), address(this).balance + extraValue);

        // mint token
        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());
        deal(address(token), address(this), amount);

        // lock for vetoken for 1 year
        token.approve(address(votingEscrow), amount);
        uint256 lockTime = 365 days;
        votingEscrow.create_lock(amount, block.timestamp + lockTime);

        // push balance to recipient
        uint256[] memory chainIdList = new uint256[](5);
        chainIdList[0] = UniversalBridgeLib.CHAINID_ARBITRUM;
        chainIdList[1] = UniversalBridgeLib.CHAINID_OPTIMISM;
        chainIdList[2] = UniversalBridgeLib.CHAINID_POLYGON;
        chainIdList[3] = UniversalBridgeLib.CHAINID_BSC;
        chainIdList[4] = UniversalBridgeLib.CHAINID_GNOSIS;
        uint256 gasLimit = 1e6;
        uint256 maxFeePerGas = 0.1 gwei;
        uint256 value = prodBeacon.getRequiredMessageValue(UniversalBridgeLib.CHAINID_ARBITRUM, gasLimit, maxFeePerGas);
        uint256 beforeBalance = address(this).balance;
        prodBeacon.broadcastVeBalanceMultiple{value: value + extraValue}(
            address(this), chainIdList, gasLimit, maxFeePerGas
        );

        if (extraValue >= block.basefee * 21000) {
            assertEqDecimal(beforeBalance - address(this).balance, value, 18, "didn't get refund");
        }
    }

    function test_refund_broadcastVeBalanceMultiple_multipleUsers(uint256 extraValue) public {
        extraValue = bound(extraValue, 0, 1e18 ether);

        // deal ETH to this
        deal(address(this), address(this).balance + extraValue);

        uint256 numUsers = 10;
        uint256 amount = 1e18;
        ERC20 token = ERC20(votingEscrow.token());

        address[] memory users = new address[](numUsers);
        for (uint8 i; i < numUsers; i++) {
            address user = address(uint160(i + 0x69));

            // whitelist user as locker
            address owner = smartWalletChecker.owner();
            vm.prank(owner);
            smartWalletChecker.allowlistAddress(user);

            vm.startPrank(user);

            // mint token
            deal(address(token), user, amount);

            // lock for vetoken for 1 year
            token.approve(address(votingEscrow), amount);
            uint256 lockTime = 365 days;
            votingEscrow.create_lock(amount, block.timestamp + lockTime);

            vm.stopPrank();

            users[i] = user;
        }

        // push balance to recipient
        uint256[] memory chainIdList = new uint256[](5);
        chainIdList[0] = UniversalBridgeLib.CHAINID_ARBITRUM;
        chainIdList[1] = UniversalBridgeLib.CHAINID_OPTIMISM;
        chainIdList[2] = UniversalBridgeLib.CHAINID_POLYGON;
        chainIdList[3] = UniversalBridgeLib.CHAINID_BSC;
        chainIdList[4] = UniversalBridgeLib.CHAINID_GNOSIS;
        uint256 gasLimit = 1e6;
        uint256 maxFeePerGas = 0.1 gwei;
        uint256 value =
            prodBeacon.getRequiredMessageValue(UniversalBridgeLib.CHAINID_ARBITRUM, gasLimit, maxFeePerGas) * numUsers;
        uint256 beforeBalance = address(this).balance;
        prodBeacon.broadcastVeBalanceMultiple{value: value + extraValue}(users, chainIdList, gasLimit, maxFeePerGas);

        if (extraValue >= block.basefee * 21000) {
            assertEqDecimal(beforeBalance - address(this).balance, value, 18, "didn't get refund");
        }
    }

    function test_fail_userNotInitialized() public {
        vm.expectRevert(VeBeacon.VeBeacon__UserNotInitialized.selector);
        beacon.broadcastVeBalance(address(0x69), 0, 0, 0);
    }

    receive() external payable {}

    /// -----------------------------------------------------------------------
    /// Internal helpers
    /// -----------------------------------------------------------------------

    function getCreate3Contract(string memory name) internal view virtual returns (address) {
        return create3.getDeployed(address(this), getCreate3ContractSalt(name));
    }

    function getCreate3ContractSalt(string memory name) internal view virtual returns (bytes32) {
        return keccak256(bytes(string.concat(name, "-v", version)));
    }

    function _verifyEquivalence(uint256 waitTime) internal {
        _verifyEquivalence(waitTime, address(this));
    }

    function _verifyEquivalence(uint256 waitTime, address user) internal {
        // check balances
        assertEqDecimal(recipient.balanceOf(user), votingEscrow.balanceOf(user), 18, "balances not equal");

        // check total supplies
        assertEqDecimal(recipient.totalSupply(), votingEscrow.totalSupply(), 18, "supplies not equal");

        // check user timestamp
        assertEq(
            recipient.user_point_history__ts(user, recipient.user_point_epoch(user)),
            votingEscrow.user_point_history__ts(user, votingEscrow.user_point_epoch(user)),
            "user point timestamp not equal"
        );

        // wait for some time
        skip(waitTime);

        // check balances
        assertEqDecimal(recipient.balanceOf(user), votingEscrow.balanceOf(user), 18, "later balances not equal");

        // check total supplies
        assertEqDecimal(recipient.totalSupply(), votingEscrow.totalSupply(), 18, "later supplies not equal");
    }

    function _verifyEquivalence(uint256 waitTime, address[] memory users) internal {
        for (uint256 i; i < users.length; i++) {
            // check balance
            assertEqDecimal(recipient.balanceOf(users[i]), votingEscrow.balanceOf(users[i]), 18, "balances not equal");
            // check user timestamp
            assertEq(
                recipient.user_point_history__ts(users[i], recipient.user_point_epoch(users[i])),
                votingEscrow.user_point_history__ts(users[i], votingEscrow.user_point_epoch(users[i])),
                "user point timestamp not equal"
            );
        }

        // check total supplies
        assertEqDecimal(recipient.totalSupply(), votingEscrow.totalSupply(), 18, "supplies not equal");

        // wait for some time
        skip(waitTime);

        // check balances
        for (uint256 i; i < users.length; i++) {
            assertEqDecimal(
                recipient.balanceOf(users[i]), votingEscrow.balanceOf(users[i]), 18, "later balances not equal"
            );
        }

        // check total supplies
        assertEqDecimal(recipient.totalSupply(), votingEscrow.totalSupply(), 18, "later supplies not equal");
    }
}
