// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {EthereumVaultConnector} from "@ethereum-vault-connector/EthereumVaultConnector.sol";

import {PositionVault} from "../src/PositionVault.sol";
import {PositionVaultFactory} from "../src/Factory/PositionVaultFactory.sol";
import {PolymarketOracle} from "../src/Oracle/PolymarketOracle.sol";
import {PositionRouter} from "../src/PositionRouter.sol";

import {MockERC1155} from "./mocks/MockERC1155.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";

/// @title BaseTest
/// @notice Base test contract with common setup for all PolyLend tests
abstract contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    EthereumVaultConnector public evc;
    PositionVaultFactory public factory;
    PolymarketOracle public oracle;
    PositionRouter public router;

    MockERC1155 public ctf; // Mock Polymarket CTF
    MockERC20 public usdc; // Mock USDC

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant POSITION_ID_YES = 1;
    uint256 public constant POSITION_ID_NO = 2;

    uint256 public constant INITIAL_CTF_BALANCE = 1000e18;
    uint256 public constant INITIAL_USDC_BALANCE = 10000e6;

    // Price: 0.6 USDC per position token (60% chance)
    uint256 public constant DEFAULT_PRICE = 0.6e6;

    /*//////////////////////////////////////////////////////////////
                                 USERS
    //////////////////////////////////////////////////////////////*/

    address public deployer;
    address public alice;
    address public bob;
    address public liquidator;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        liquidator = makeAddr("liquidator");

        vm.startPrank(deployer);

        // Deploy core contracts
        evc = new EthereumVaultConnector();
        ctf = new MockERC1155();
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy PolyLend contracts
        factory = new PositionVaultFactory(address(evc), address(ctf));
        oracle = new PolymarketOracle(deployer);
        router = new PositionRouter(address(evc), address(factory));

        vm.stopPrank();

        // Setup initial balances
        _setupBalances();
    }

    function _setupBalances() internal {
        // Mint CTF tokens to users
        ctf.mint(alice, POSITION_ID_YES, INITIAL_CTF_BALANCE);
        ctf.mint(alice, POSITION_ID_NO, INITIAL_CTF_BALANCE);
        ctf.mint(bob, POSITION_ID_YES, INITIAL_CTF_BALANCE);
        ctf.mint(bob, POSITION_ID_NO, INITIAL_CTF_BALANCE);

        // Mint USDC to users
        usdc.mint(alice, INITIAL_USDC_BALANCE);
        usdc.mint(bob, INITIAL_USDC_BALANCE);
        usdc.mint(liquidator, INITIAL_USDC_BALANCE * 10);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a vault for a position and set its price
    function _createVaultWithPrice(uint256 positionId, string memory name, string memory symbol, uint256 price)
        internal
        returns (address vault)
    {
        vm.prank(deployer);
        vault = factory.createVault(positionId, name, symbol);

        vm.prank(deployer);
        oracle.setPrice(vault, price);
    }

    /// @notice Approve and deposit CTF tokens into a vault
    function _depositToVault(address user, address vault, uint256 positionId, uint256 amount) internal {
        vm.startPrank(user);
        ctf.setApprovalForAll(vault, true);
        PositionVault(vault).deposit(amount, user);
        vm.stopPrank();
    }
}
