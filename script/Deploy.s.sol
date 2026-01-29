// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {PositionVaultFactory} from "../src/core/PositionVaultFactory.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {LiquidationEngine} from "../src/core/LiquidationEngine.sol";
import {InterestRateModel} from "../src/core/InterestRateModel.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import {PolyLendRouter} from "../src/periphery/PolyLendRouter.sol";

/// @title Deploy
/// @notice Deployment script for PolyLend protocol
contract Deploy is Script {
    /*//////////////////////////////////////////////////////////////
                          POLYGON MAINNET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    // Polymarket CTF (Conditional Token Framework) on Polygon
    address constant POLYMARKET_CTF = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;

    // USDC on Polygon
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    /*//////////////////////////////////////////////////////////////
                            DEPLOYED CONTRACTS
    //////////////////////////////////////////////////////////////*/

    PositionVaultFactory public factory;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    LiquidationEngine public liquidationEngine;
    InterestRateModel public interestRateModel;
    PriceOracle public priceOracle;
    PolyLendRouter public router;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying PolyLend protocol...");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy InterestRateModel
        interestRateModel = new InterestRateModel(deployer);
        console2.log("InterestRateModel:", address(interestRateModel));

        // 2. Deploy PriceOracle
        priceOracle = new PriceOracle(deployer);
        console2.log("PriceOracle:", address(priceOracle));

        // 3. Deploy PositionVaultFactory
        factory = new PositionVaultFactory(POLYMARKET_CTF, deployer);
        console2.log("PositionVaultFactory:", address(factory));

        // 4. Deploy LendingPool
        lendingPool = new LendingPool(USDC, address(interestRateModel), deployer);
        console2.log("LendingPool:", address(lendingPool));

        // 5. Deploy CollateralManager
        collateralManager = new CollateralManager(address(lendingPool), address(priceOracle), deployer);
        console2.log("CollateralManager:", address(collateralManager));

        // 6. Deploy LiquidationEngine
        liquidationEngine = new LiquidationEngine(
            address(lendingPool),
            address(collateralManager),
            address(priceOracle),
            deployer
        );
        console2.log("LiquidationEngine:", address(liquidationEngine));

        // 7. Deploy Router
        router = new PolyLendRouter(address(factory), address(lendingPool), address(collateralManager));
        console2.log("PolyLendRouter:", address(router));

        // 8. Connect contracts
        lendingPool.setCollateralManager(address(collateralManager));
        collateralManager.setLiquidationEngine(address(liquidationEngine));

        vm.stopBroadcast();

        // Log summary
        _logDeploymentSummary();
    }

    function _logDeploymentSummary() internal view {
        console2.log("\n========== DEPLOYMENT SUMMARY ==========");
        console2.log("InterestRateModel:    ", address(interestRateModel));
        console2.log("PriceOracle:          ", address(priceOracle));
        console2.log("PositionVaultFactory: ", address(factory));
        console2.log("LendingPool:          ", address(lendingPool));
        console2.log("CollateralManager:    ", address(collateralManager));
        console2.log("LiquidationEngine:    ", address(liquidationEngine));
        console2.log("PolyLendRouter:       ", address(router));
        console2.log("=========================================\n");
    }
}

/// @title DeployTestnet
/// @notice Deployment script for testnet with mock contracts
contract DeployTestnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying PolyLend to testnet...");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        MockERC20 usdc = new MockERC20("Mock USDC", "USDC", 6);
        MockERC1155 ctf = new MockERC1155();

        console2.log("Mock USDC:", address(usdc));
        console2.log("Mock CTF:", address(ctf));

        // Deploy protocol
        InterestRateModel irm = new InterestRateModel(deployer);
        PriceOracle oracle = new PriceOracle(deployer);
        PositionVaultFactory factory = new PositionVaultFactory(address(ctf), deployer);
        LendingPool pool = new LendingPool(address(usdc), address(irm), deployer);
        CollateralManager cm = new CollateralManager(address(pool), address(oracle), deployer);
        LiquidationEngine le = new LiquidationEngine(address(pool), address(cm), address(oracle), deployer);
        PolyLendRouter router = new PolyLendRouter(address(factory), address(pool), address(cm));

        // Connect
        pool.setCollateralManager(address(cm));
        cm.setLiquidationEngine(address(le));

        // Create example vault
        address vault = factory.createVault(1, "PolyLend BTC 100k YES", "pBTC100kY");
        oracle.setPrice(vault, 60_000_000); // $0.60
        cm.setCollateralConfig(vault, 6000, 7500, 500);

        // Mint test tokens
        usdc.mint(deployer, 1_000_000e6);
        ctf.mint(deployer, 1, 10_000e18);

        vm.stopBroadcast();

        console2.log("\n========== TESTNET DEPLOYMENT ==========");
        console2.log("Mock USDC:            ", address(usdc));
        console2.log("Mock CTF:             ", address(ctf));
        console2.log("InterestRateModel:    ", address(irm));
        console2.log("PriceOracle:          ", address(oracle));
        console2.log("PositionVaultFactory: ", address(factory));
        console2.log("LendingPool:          ", address(pool));
        console2.log("CollateralManager:    ", address(cm));
        console2.log("LiquidationEngine:    ", address(le));
        console2.log("PolyLendRouter:       ", address(router));
        console2.log("Example Vault:        ", vault);
        console2.log("=========================================\n");
    }
}

// Mock contracts for testnet
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}
