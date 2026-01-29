// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PositionVaultFactory} from "../src/Factory/PositionVaultFactory.sol";
import {PolymarketOracle} from "../src/Oracle/PolymarketOracle.sol";

/// @title CreateVault
/// @notice Script to create a new PositionVault for a Polymarket position
/// @dev Run with environment variables:
///      FACTORY_ADDRESS=0x... ORACLE_ADDRESS=0x... POSITION_ID=123 VAULT_NAME="PolyLend YES" VAULT_SYMBOL="pYES" PRICE=600000
///      forge script script/CreateVault.s.sol:CreateVault --rpc-url polygon --broadcast
contract CreateVault is Script {
    function run() external {
        // Get deployment parameters from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        uint256 positionId = vm.envUint("POSITION_ID");
        string memory vaultName = vm.envString("VAULT_NAME");
        string memory vaultSymbol = vm.envString("VAULT_SYMBOL");
        uint256 price = vm.envUint("PRICE"); // Price in USDC (6 decimals)

        console2.log("Creating vault for position:", positionId);
        console2.log("Name:", vaultName);
        console2.log("Symbol:", vaultSymbol);
        console2.log("Initial Price:", price);

        vm.startBroadcast(deployerPrivateKey);

        // Create vault
        PositionVaultFactory factory = PositionVaultFactory(factoryAddress);
        address vault = factory.createVault(positionId, vaultName, vaultSymbol);
        console2.log("Vault created at:", vault);

        // Set price
        PolymarketOracle oracle = PolymarketOracle(oracleAddress);
        oracle.setPrice(vault, price);
        console2.log("Price set to:", price);

        vm.stopBroadcast();

        console2.log("\n=== Vault Created ===");
        console2.log("Position ID:", positionId);
        console2.log("Vault Address:", vault);
        console2.log("Price (USDC):", price);
        console2.log("=====================\n");
    }
}

/// @title UpdatePrice
/// @notice Script to update the price of a PositionVault
/// @dev Run with: ORACLE_ADDRESS=0x... VAULT_ADDRESS=0x... PRICE=600000 forge script script/CreateVault.s.sol:UpdatePrice --rpc-url polygon --broadcast
contract UpdatePrice is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        uint256 price = vm.envUint("PRICE");

        console2.log("Updating price for vault:", vaultAddress);
        console2.log("New price:", price);

        vm.startBroadcast(deployerPrivateKey);

        PolymarketOracle oracle = PolymarketOracle(oracleAddress);
        oracle.setPrice(vaultAddress, price);

        vm.stopBroadcast();

        console2.log("Price updated successfully!");
    }
}

/// @title BatchUpdatePrices
/// @notice Script to update multiple vault prices at once
/// @dev Prices are read from a JSON file
contract BatchUpdatePrices is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");

        // Example: Update multiple vaults
        // In production, read from JSON config file
        address[] memory vaults = new address[](2);
        uint256[] memory prices = new uint256[](2);

        // These would come from environment or config file
        vaults[0] = vm.envAddress("VAULT_1");
        vaults[1] = vm.envAddress("VAULT_2");
        prices[0] = vm.envUint("PRICE_1");
        prices[1] = vm.envUint("PRICE_2");

        console2.log("Batch updating prices...");

        vm.startBroadcast(deployerPrivateKey);

        PolymarketOracle oracle = PolymarketOracle(oracleAddress);
        oracle.setPrices(vaults, prices);

        vm.stopBroadcast();

        console2.log("Prices updated successfully!");
    }
}
