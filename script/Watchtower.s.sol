// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Watchtower} from "../src/Watchtower.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("Watchtower.sol:Watchtower", constructorArgs, flags);
        Watchtower hook = Watchtower(flags);
        console.log("Watchtower deployed at address:", address(hook));

        vm.stopBroadcast();
    }
}
