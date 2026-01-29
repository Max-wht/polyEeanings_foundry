// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {PositionVault} from "../../src/core/PositionVault.sol";
import {PositionVaultFactory} from "../../src/core/PositionVaultFactory.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {CollateralManager} from "../../src/core/CollateralManager.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";
import {InterestRateModel} from "../../src/core/InterestRateModel.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";

/// @title PolyLendForkTest
/// @notice Fork test using real Polygon mainnet contracts
contract PolyLendForkTest is Test {
    /*//////////////////////////////////////////////////////////////
                          POLYGON MAINNET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    // Polymarket Conditional Token Framework (CTF)
    address constant POLYMARKET_CTF = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;

    // USDC on Polygon
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    // A known position ID from Polymarket (example: Presidential Election market)
    // You can find position IDs from Polymarket's API or contract events
    uint256 constant EXAMPLE_POSITION_ID = 52114319501245915516055106046884209969926127482827954674443846427813813222426;

    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    IERC1155 public ctf;
    IERC20 public usdc;

    PositionVaultFactory public factory;
    LendingPool public lendingPool;
    CollateralManager public collateralManager;
    LiquidationEngine public liquidationEngine;
    InterestRateModel public interestRateModel;
    PriceOracle public priceOracle;
    PositionVault public vault;

    /*//////////////////////////////////////////////////////////////
                                 USERS
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public alice;
    address public bob;

    // Whale addresses for impersonation (find addresses with USDC/CTF balance)
    address constant USDC_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // Binance

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Create users
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Get real contract references
        ctf = IERC1155(POLYMARKET_CTF);
        usdc = IERC20(USDC);

        vm.startPrank(owner);

        // Deploy PolyLend protocol
        interestRateModel = new InterestRateModel(owner);
        priceOracle = new PriceOracle(owner);
        factory = new PositionVaultFactory(POLYMARKET_CTF, owner);
        lendingPool = new LendingPool(USDC, address(interestRateModel), owner);
        collateralManager = new CollateralManager(address(lendingPool), address(priceOracle), owner);
        liquidationEngine = new LiquidationEngine(
            address(lendingPool), address(collateralManager), address(priceOracle), owner
        );

        // Connect contracts
        lendingPool.setCollateralManager(address(collateralManager));
        collateralManager.setLiquidationEngine(address(liquidationEngine));

        // Create a vault for the example position
        address vaultAddr = factory.createVault(EXAMPLE_POSITION_ID, "PolyLend Position", "pPOS");
        vault = PositionVault(vaultAddr);

        // Configure collateral: 60% LTV, 75% liquidation threshold, 5% bonus
        priceOracle.setPrice(vaultAddr, 50_000_000); // $0.50
        collateralManager.setCollateralConfig(vaultAddr, 6000, 7500, 500);

        vm.stopPrank();

        // Fund test users with USDC from whale
        _fundUsersWithUSDC();
    }

    function _fundUsersWithUSDC() internal {
        uint256 amount = 10_000e6; // 10,000 USDC

        // Use deal to directly set USDC balance
        deal(USDC, alice, amount);
        deal(USDC, bob, amount);
    }

    /*//////////////////////////////////////////////////////////////
                               TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_deploymentSuccessful() public view {
        assertEq(address(factory.ctf()), POLYMARKET_CTF);
        assertEq(lendingPool.asset(), USDC);
        assertTrue(address(vault) != address(0));
    }

    function test_fork_depositUSDCLiquidity() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        vm.startPrank(alice);
        usdc.approve(address(lendingPool), depositAmount);

        uint256 balanceBefore = usdc.balanceOf(alice);
        lendingPool.deposit(depositAmount);
        uint256 balanceAfter = usdc.balanceOf(alice);

        vm.stopPrank();

        assertEq(balanceBefore - balanceAfter, depositAmount);
        assertGt(lendingPool.sharesOf(alice), 0);

        console2.log("Alice deposited USDC:", depositAmount / 1e6);
        console2.log("Alice shares:", lendingPool.sharesOf(alice));
    }

    function test_fork_withdrawUSDC() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(alice);
        usdc.approve(address(lendingPool), depositAmount);
        uint256 shares = lendingPool.deposit(depositAmount);

        uint256 withdrawn = lendingPool.withdraw(shares);
        vm.stopPrank();

        assertApproxEqAbs(withdrawn, depositAmount, 1); // Allow 1 wei difference
        assertEq(lendingPool.sharesOf(alice), 0);
    }

    function test_fork_checkPolymarketCTF() public view {
        // Check if CTF contract is accessible
        bool supportsInterface = ctf.supportsInterface(0xd9b67a26); // ERC1155 interface ID
        assertTrue(supportsInterface, "CTF should support ERC1155");

        console2.log("Polymarket CTF address:", POLYMARKET_CTF);
        console2.log("Supports ERC1155:", supportsInterface);
    }

    function test_fork_utilizationAndRates() public {
        // Bob provides liquidity
        vm.startPrank(bob);
        usdc.approve(address(lendingPool), 5000e6);
        lendingPool.deposit(5000e6);
        vm.stopPrank();

        // Check rates
        (uint256 depositRate, uint256 borrowRate) = lendingPool.getCurrentRates();

        console2.log("Utilization rate:", lendingPool.getUtilizationRate());
        console2.log("Deposit rate (per second):", depositRate);
        console2.log("Borrow rate (per second):", borrowRate);
        console2.log("Available liquidity:", lendingPool.availableLiquidity() / 1e6, "USDC");
    }

    /// @notice This test requires finding a wallet with CTF positions
    /// @dev Uncomment and update CTF_HOLDER when you have a valid address
    // function test_fork_depositCTFAsCollateral() public {
    //     address CTF_HOLDER = address(0); // TODO: Find a holder of the position
    //
    //     vm.startPrank(CTF_HOLDER);
    //     uint256 ctfBalance = ctf.balanceOf(CTF_HOLDER, EXAMPLE_POSITION_ID);
    //     console2.log("CTF holder balance:", ctfBalance);
    //
    //     if (ctfBalance > 0) {
    //         // Deposit CTF to vault
    //         ctf.setApprovalForAll(address(vault), true);
    //         vault.deposit(ctfBalance, CTF_HOLDER);
    //
    //         // Deposit as collateral
    //         vault.approve(address(collateralManager), ctfBalance);
    //         collateralManager.depositCollateral(address(vault), ctfBalance);
    //
    //         console2.log("Collateral deposited:", ctfBalance);
    //         console2.log("Max borrow:", collateralManager.getMaxBorrowAmount(CTF_HOLDER));
    //     }
    //     vm.stopPrank();
    // }
}
