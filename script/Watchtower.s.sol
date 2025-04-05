// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";


import {Watchtower} from "../src/Watchtower.sol";

contract Deploy is Script {
    address poolManagerAddress;
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function setUp() public {
        if (block.chainid == 1) { // Mainnet
            poolManagerAddress = 0x000000000004444c5dc75cB358380D2e3dE08A90;
        } else if (block.chainid == 130) { // Unichain
            poolManagerAddress = 0x1F98400000000000000000000000000000000004;
        } else if (block.chainid == 10) { // Optimism
            poolManagerAddress =  0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        } else if (block.chainid == 84532) { // Base Sepolia
            poolManagerAddress = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
        } else if (block.chainid == 137) { // Polygon
            poolManagerAddress = 0x67366782805870060151383F4BbFF9daB53e5cD6;
        } else if (block.chainid == 2442) { // Polygon Cardona
            poolManagerAddress = 0x67366782805870060151383F4BbFF9daB53e5cD6;
        } else if (block.chainid == 80002) { // Polygon Amboy
            poolManagerAddress = 0x67366782805870060151383F4BbFF9daB53e5cD6;
        } else if (block.chainid == 1301) { // Unichain Sepolia
            poolManagerAddress = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
        } else {
            revert("Unsupported network");
        }
    }

    function run() public {
        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.AFTER_SWAP_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManagerAddress);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(Watchtower).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        Watchtower watchtower = new Watchtower{salt: salt}(IPoolManager(poolManagerAddress));
        require(address(watchtower) == hookAddress, "Watchtower.s: hook address mismatch");

        console.log("Watchtower deployed at address:", address(watchtower));
    }
}
