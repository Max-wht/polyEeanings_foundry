// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../Base.t.sol";
import {PolymarketOracle} from "../../src/Oracle/PolymarketOracle.sol";

/// @title PolymarketOracleTest
/// @notice Unit tests for PolymarketOracle contract
contract PolymarketOracleTest is BaseTest {
    address public vault;

    function setUp() public override {
        super.setUp();

        // Create a vault for testing
        vm.prank(deployer);
        vault = factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES");
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(oracle.name(), "PolymarketOracle");
        assertEq(oracle.owner(), deployer);
        assertEq(oracle.defaultSpreadBps(), 200); // 2%
        assertEq(oracle.maxStaleness(), 1 days);
    }

    /*//////////////////////////////////////////////////////////////
                            SET PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setPrice() public {
        uint256 price = 0.6e6; // 0.6 USDC per position token

        vm.prank(deployer);
        oracle.setPrice(vault, price);

        (uint256 storedPrice, uint256 lastUpdated, bool isValid) = oracle.getPriceData(vault);

        assertEq(storedPrice, price);
        assertEq(lastUpdated, block.timestamp);
        assertTrue(isValid);
    }

    function test_setPrice_emitsEvent() public {
        uint256 price = 0.6e6;

        vm.expectEmit(true, false, false, true);
        emit PolymarketOracle.PriceUpdated(vault, 0, price, block.timestamp);

        vm.prank(deployer);
        oracle.setPrice(vault, price);
    }

    function test_revert_setPrice_notOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        oracle.setPrice(vault, 0.6e6);
    }

    function test_revert_setPrice_zeroPrice() public {
        vm.prank(deployer);
        vm.expectRevert(PolymarketOracle.PolymarketOracle__InvalidPrice.selector);
        oracle.setPrice(vault, 0);
    }

    function test_setPrices_batch() public {
        address vault2 = factory.createVault(POSITION_ID_NO, "PolyLend NO", "pNO");

        address[] memory vaults = new address[](2);
        vaults[0] = vault;
        vaults[1] = vault2;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 0.6e6;
        prices[1] = 0.4e6;

        vm.prank(deployer);
        oracle.setPrices(vaults, prices);

        (uint256 price1,,) = oracle.getPriceData(vault);
        (uint256 price2,,) = oracle.getPriceData(vault2);

        assertEq(price1, 0.6e6);
        assertEq(price2, 0.4e6);
    }

    /*//////////////////////////////////////////////////////////////
                          GET QUOTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getQuote() public {
        uint256 price = 0.6e6; // 0.6 USDC per position token

        vm.prank(deployer);
        oracle.setPrice(vault, price);

        // 100 position tokens (18 decimals) should return 60 USDC (6 decimals)
        uint256 inAmount = 100e18;
        uint256 outAmount = oracle.getQuote(inAmount, vault, address(usdc));

        assertEq(outAmount, 60e6); // 100 * 0.6 = 60 USDC
    }

    function test_getQuote_fractional() public {
        uint256 price = 0.75e6; // 0.75 USDC per position token

        vm.prank(deployer);
        oracle.setPrice(vault, price);

        uint256 inAmount = 1e18; // 1 position token
        uint256 outAmount = oracle.getQuote(inAmount, vault, address(usdc));

        assertEq(outAmount, 0.75e6); // 0.75 USDC
    }

    function test_revert_getQuote_priceNotSet() public {
        vm.expectRevert(PolymarketOracle.PolymarketOracle__PriceNotSet.selector);
        oracle.getQuote(100e18, vault, address(usdc));
    }

    function test_revert_getQuote_stalePrice() public {
        vm.prank(deployer);
        oracle.setPrice(vault, 0.6e6);

        // Fast forward beyond staleness threshold
        vm.warp(block.timestamp + 1 days + 1);

        vm.expectRevert(PolymarketOracle.PolymarketOracle__StalePrice.selector);
        oracle.getQuote(100e18, vault, address(usdc));
    }

    function test_revert_getQuote_invalidatedPrice() public {
        vm.startPrank(deployer);
        oracle.setPrice(vault, 0.6e6);
        oracle.invalidatePrice(vault);
        vm.stopPrank();

        vm.expectRevert(PolymarketOracle.PolymarketOracle__PriceNotSet.selector);
        oracle.getQuote(100e18, vault, address(usdc));
    }

    /*//////////////////////////////////////////////////////////////
                         GET QUOTES (BID/ASK) TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getQuotes_defaultSpread() public {
        uint256 price = 1e6; // 1 USDC per position token for easy calculation

        vm.prank(deployer);
        oracle.setPrice(vault, price);

        uint256 inAmount = 100e18;
        (uint256 bidOut, uint256 askOut) = oracle.getQuotes(inAmount, vault, address(usdc));

        // Default spread is 2% (200 bps)
        // Mid = 100 USDC
        // Bid = 100 - 1% = 99 USDC
        // Ask = 100 + 1% = 101 USDC
        assertEq(bidOut, 99e6);
        assertEq(askOut, 101e6);
    }

    function test_getQuotes_customSpread() public {
        uint256 price = 1e6;

        vm.startPrank(deployer);
        oracle.setPrice(vault, price);
        oracle.setSpread(vault, 1000); // 10% spread
        vm.stopPrank();

        uint256 inAmount = 100e18;
        (uint256 bidOut, uint256 askOut) = oracle.getQuotes(inAmount, vault, address(usdc));

        // Spread is 10%
        // Bid = 100 - 5% = 95 USDC
        // Ask = 100 + 5% = 105 USDC
        assertEq(bidOut, 95e6);
        assertEq(askOut, 105e6);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setSpread() public {
        vm.prank(deployer);
        oracle.setSpread(vault, 500); // 5%

        assertEq(oracle.spreads(vault), 500);
    }

    function test_revert_setSpread_tooHigh() public {
        vm.prank(deployer);
        vm.expectRevert(PolymarketOracle.PolymarketOracle__InvalidSpread.selector);
        oracle.setSpread(vault, 5001); // > 50%
    }

    function test_setDefaultSpread() public {
        vm.prank(deployer);
        oracle.setDefaultSpread(300); // 3%

        assertEq(oracle.defaultSpreadBps(), 300);
    }

    function test_setMaxStaleness() public {
        vm.prank(deployer);
        oracle.setMaxStaleness(2 days);

        assertEq(oracle.maxStaleness(), 2 days);
    }

    function test_invalidatePrice() public {
        vm.startPrank(deployer);
        oracle.setPrice(vault, 0.6e6);
        oracle.invalidatePrice(vault);
        vm.stopPrank();

        (,, bool isValid) = oracle.getPriceData(vault);
        assertFalse(isValid);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isPriceFresh() public {
        vm.prank(deployer);
        oracle.setPrice(vault, 0.6e6);

        assertTrue(oracle.isPriceFresh(vault));

        // Fast forward
        vm.warp(block.timestamp + 1 days + 1);
        assertFalse(oracle.isPriceFresh(vault));
    }

    function test_isPriceFresh_invalidated() public {
        vm.startPrank(deployer);
        oracle.setPrice(vault, 0.6e6);
        oracle.invalidatePrice(vault);
        vm.stopPrank();

        assertFalse(oracle.isPriceFresh(vault));
    }

    /*//////////////////////////////////////////////////////////////
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_getQuote(uint256 price, uint256 amount) public {
        price = bound(price, 1, 1e6); // 0.000001 to 1 USDC
        amount = bound(amount, 1e18, 1000000e18);

        vm.prank(deployer);
        oracle.setPrice(vault, price);

        uint256 outAmount = oracle.getQuote(amount, vault, address(usdc));

        // outAmount = amount * price / 1e18
        uint256 expected = (amount * price) / 1e18;
        assertEq(outAmount, expected);
    }
}
