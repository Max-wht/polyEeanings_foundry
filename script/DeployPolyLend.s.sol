// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PositionVaultFactory} from "../src/Factory/PositionVaultFactory.sol";
import {PolymarketOracle} from "../src/Oracle/PolymarketOracle.sol";
import {PositionRouter} from "../src/PositionRouter.sol";

/// @title DeployPolyLend
/// @notice Deployment script for PolyLend protocol on Polygon
/// @dev Run with: forge script script/DeployPolyLend.s.sol:DeployPolyLend --rpc-url polygon --broadcast
contract DeployPolyLend is Script {
    /*//////////////////////////////////////////////////////////////
                          POLYGON MAINNET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    // Polymarket CTF (Conditional Token Framework) on Polygon
    address constant POLYMARKET_CTF = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;

    // USDC on Polygon
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    // Euler EVC on Polygon (placeholder - need actual address)
    // TODO: Update with actual Euler EVC address on Polygon
    address constant EULER_EVC = 0x0000000000000000000000000000000000000000;

    /*//////////////////////////////////////////////////////////////
                               DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying PolyLend contracts...");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PositionVaultFactory
        PositionVaultFactory factory = new PositionVaultFactory(EULER_EVC, POLYMARKET_CTF);
        console2.log("PositionVaultFactory deployed at:", address(factory));

        // 2. Deploy PolymarketOracle
        PolymarketOracle oracle = new PolymarketOracle(deployer);
        console2.log("PolymarketOracle deployed at:", address(oracle));

        // 3. Deploy PositionRouter
        PositionRouter router = new PositionRouter(EULER_EVC, address(factory));
        console2.log("PositionRouter deployed at:", address(router));

        vm.stopBroadcast();

        // Log summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("PositionVaultFactory:", address(factory));
        console2.log("PolymarketOracle:", address(oracle));
        console2.log("PositionRouter:", address(router));
        console2.log("========================\n");
    }
}

/// @title DeployPolyLendTestnet
/// @notice Deployment script for PolyLend protocol on Polygon Amoy testnet
/// @dev Run with: forge script script/DeployPolyLend.s.sol:DeployPolyLendTestnet --rpc-url amoy --broadcast
contract DeployPolyLendTestnet is Script {
    /*//////////////////////////////////////////////////////////////
                       POLYGON AMOY TESTNET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    // Mock CTF address (will be deployed)
    address public mockCtf;
    // Mock USDC address (will be deployed)
    address public mockUsdc;
    // Mock EVC address (will be deployed)
    address public mockEvc;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying PolyLend contracts to testnet...");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock contracts for testing
        MockERC1155 ctf = new MockERC1155();
        mockCtf = address(ctf);
        console2.log("MockCTF deployed at:", mockCtf);

        MockERC20 usdc = new MockERC20("Mock USDC", "USDC", 6);
        mockUsdc = address(usdc);
        console2.log("MockUSDC deployed at:", mockUsdc);

        // Deploy EVC
        EthereumVaultConnector evc = new EthereumVaultConnector();
        mockEvc = address(evc);
        console2.log("EVC deployed at:", mockEvc);

        // 2. Deploy PolyLend contracts
        PositionVaultFactory factory = new PositionVaultFactory(mockEvc, mockCtf);
        console2.log("PositionVaultFactory deployed at:", address(factory));

        PolymarketOracle oracle = new PolymarketOracle(deployer);
        console2.log("PolymarketOracle deployed at:", address(oracle));

        PositionRouter router = new PositionRouter(mockEvc, address(factory));
        console2.log("PositionRouter deployed at:", address(router));

        // 3. Setup example vaults
        uint256 positionIdYes = 1;
        uint256 positionIdNo = 2;

        address vaultYes = factory.createVault(positionIdYes, "PolyLend BTC 100k YES", "pBTC100kY");
        address vaultNo = factory.createVault(positionIdNo, "PolyLend BTC 100k NO", "pBTC100kN");

        console2.log("Example Vault YES:", vaultYes);
        console2.log("Example Vault NO:", vaultNo);

        // 4. Set example prices (0.6 USDC for YES, 0.4 USDC for NO)
        oracle.setPrice(vaultYes, 0.6e6);
        oracle.setPrice(vaultNo, 0.4e6);

        // 5. Mint some test tokens to deployer
        ctf.mint(deployer, positionIdYes, 1000e18);
        ctf.mint(deployer, positionIdNo, 1000e18);
        usdc.mint(deployer, 10000e6);

        vm.stopBroadcast();

        // Log summary
        console2.log("\n=== Testnet Deployment Summary ===");
        console2.log("MockCTF:", mockCtf);
        console2.log("MockUSDC:", mockUsdc);
        console2.log("EVC:", mockEvc);
        console2.log("PositionVaultFactory:", address(factory));
        console2.log("PolymarketOracle:", address(oracle));
        console2.log("PositionRouter:", address(router));
        console2.log("Vault YES:", vaultYes);
        console2.log("Vault NO:", vaultNo);
        console2.log("==================================\n");
    }
}

// Import mock contracts for testnet deployment
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EthereumVaultConnector} from "@ethereum-vault-connector/EthereumVaultConnector.sol";

/// @notice Simple Mock ERC1155 for testnet
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

/// @notice Simple Mock ERC20 for testnet
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
