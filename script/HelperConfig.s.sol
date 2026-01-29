// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

/// @title HelperConfig
/// @notice Configuration helper for different networks
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct NetworkConfig {
        address ctf; // Polymarket Conditional Token Framework
        address usdc; // USDC stablecoin
        address evc; // Euler Vault Connector
        address eulerUsdcVault; // Euler USDC lending vault
        uint256 deployerKey;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Chain IDs
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant POLYGON_AMOY_CHAIN_ID = 80002;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    // Polygon Mainnet Addresses
    address public constant POLYGON_CTF = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;
    address public constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    // TODO: Add actual Euler addresses when deployed on Polygon
    address public constant POLYGON_EVC = address(0);
    address public constant POLYGON_EULER_USDC = address(0);

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    NetworkConfig public activeNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        if (block.chainid == POLYGON_CHAIN_ID) {
            activeNetworkConfig = getPolygonConfig();
        } else if (block.chainid == POLYGON_AMOY_CHAIN_ID) {
            activeNetworkConfig = getPolygonAmoyConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          NETWORK CONFIGS
    //////////////////////////////////////////////////////////////*/

    function getPolygonConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ctf: POLYGON_CTF,
            usdc: POLYGON_USDC,
            evc: POLYGON_EVC,
            eulerUsdcVault: POLYGON_EULER_USDC,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getPolygonAmoyConfig() public view returns (NetworkConfig memory) {
        // For testnet, we'll deploy mock contracts
        // Return empty addresses that will be filled by deployment script
        return NetworkConfig({
            ctf: address(0),
            usdc: address(0),
            evc: address(0),
            eulerUsdcVault: address(0),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        // For local testing, return default anvil key
        uint256 defaultKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        return NetworkConfig({
            ctf: address(0),
            usdc: address(0),
            evc: address(0),
            eulerUsdcVault: address(0),
            deployerKey: vm.envOr("PRIVATE_KEY", defaultKey)
        });
    }
}
