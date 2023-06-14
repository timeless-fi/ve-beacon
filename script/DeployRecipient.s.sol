// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "universal-bridge-lib/UniversalBridgeLib.sol";

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {VeRecipient} from "../src/VeRecipient.sol";
import {VeRecipientAMB} from "../src/recipients/VeRecipientAMB.sol";
import {VeRecipientArbitrum} from "../src/recipients/VeRecipientArbitrum.sol";
import {VeRecipientOptimism} from "../src/recipients/VeRecipientOptimism.sol";
import {VeRecipientPolygon} from "../src/recipients/VeRecipientPolygon.sol";

contract DeployRecipientScript is CREATE3Script {
    error ChainIdNotSupported(uint256 chainid);

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (VeRecipient recipient) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        // deploy recipient
        if (block.chainid == UniversalBridgeLib.CHAINID_ARBITRUM) {
            recipient = VeRecipient(
                create3.deploy(
                    getCreate3ContractSalt("VeRecipient"),
                    bytes.concat(
                        type(VeRecipientArbitrum).creationCode,
                        abi.encode(getCreate3Contract("VeBeacon"), vm.envAddress("OWNER_ARBITRUM"))
                    )
                )
            );
        } else if (block.chainid == UniversalBridgeLib.CHAINID_OPTIMISM) {
            recipient = VeRecipient(
                create3.deploy(
                    getCreate3ContractSalt("VeRecipient"),
                    bytes.concat(
                        type(VeRecipientOptimism).creationCode,
                        abi.encode(getCreate3Contract("VeBeacon"), vm.envAddress("OWNER_OPTIMISM"))
                    )
                )
            );
        } else if (block.chainid == UniversalBridgeLib.CHAINID_POLYGON) {
            recipient = VeRecipient(
                create3.deploy(
                    getCreate3ContractSalt("VeRecipient"),
                    bytes.concat(
                        type(VeRecipientPolygon).creationCode,
                        abi.encode(getCreate3Contract("VeBeacon"), vm.envAddress("OWNER_POLYGON"))
                    )
                )
            );
        } else if (block.chainid == UniversalBridgeLib.CHAINID_BSC) {
            recipient = VeRecipient(
                create3.deploy(
                    getCreate3ContractSalt("VeRecipient"),
                    bytes.concat(
                        type(VeRecipientAMB).creationCode,
                        abi.encode(
                            getCreate3Contract("VeBeacon"), vm.envAddress("OWNER_BSC"), UniversalBridgeLib.BRIDGE_BSC
                        )
                    )
                )
            );
        } else if (block.chainid == UniversalBridgeLib.CHAINID_GNOSIS) {
            recipient = VeRecipient(
                create3.deploy(
                    getCreate3ContractSalt("VeRecipient"),
                    bytes.concat(
                        type(VeRecipientAMB).creationCode,
                        abi.encode(
                            getCreate3Contract("VeBeacon"),
                            vm.envAddress("OWNER_GNOSIS"),
                            UniversalBridgeLib.BRIDGE_GNOSIS
                        )
                    )
                )
            );
        } else {
            revert ChainIdNotSupported(block.chainid);
        }

        vm.stopBroadcast();
    }
}
