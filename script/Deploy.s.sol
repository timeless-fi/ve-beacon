// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {VeBeacon} from "../src/VeBeacon.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (VeBeacon c) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 param = 123;

        vm.startBroadcast(deployerPrivateKey);

        c = VeBeacon(
            create3.deploy(
                getCreate3ContractSalt("VeBeacon"), bytes.concat(type(VeBeacon).creationCode, abi.encode(param))
            )
        );

        vm.stopBroadcast();
    }
}
