// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../Base.t.sol";
import {PositionVault} from "../../src/PositionVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title PositionVaultTest
/// @notice Unit tests for PositionVault contract
contract PositionVaultTest is BaseTest {
    PositionVault public vault;

    function setUp() public override {
        super.setUp();

        // Create a vault for YES position
        vm.prank(deployer);
        vault = PositionVault(factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES"));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(vault.name(), "PolyLend YES");
        assertEq(vault.symbol(), "pYES");
        assertEq(vault.i_positionId(), POSITION_ID_YES);
        assertEq(address(vault.i_market()), address(ctf));
        assertEq(address(vault.i_factory()), address(factory));
        assertEq(vault.EVC(), address(evc));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deposit() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);

        uint256 ctfBefore = ctf.balanceOf(alice, POSITION_ID_YES);
        uint256 sharesBefore = vault.balanceOf(alice);

        vault.deposit(depositAmount, alice);

        uint256 ctfAfter = ctf.balanceOf(alice, POSITION_ID_YES);
        uint256 sharesAfter = vault.balanceOf(alice);

        vm.stopPrank();

        // Check balances
        assertEq(ctfBefore - ctfAfter, depositAmount, "CTF not transferred");
        assertEq(sharesAfter - sharesBefore, depositAmount, "Shares not minted (1:1)");
        assertEq(vault.totalAssets(), depositAmount, "Total assets mismatch");
    }

    function test_deposit_multipleUsers() public {
        uint256 aliceDeposit = 100e18;
        uint256 bobDeposit = 200e18;

        // Alice deposits
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(aliceDeposit, alice);
        vm.stopPrank();

        // Bob deposits
        vm.startPrank(bob);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(bobDeposit, bob);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), aliceDeposit);
        assertEq(vault.balanceOf(bob), bobDeposit);
        assertEq(vault.totalAssets(), aliceDeposit + bobDeposit);
    }

    function test_deposit_toOther() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, bob); // Alice deposits, Bob receives shares
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), depositAmount);
    }

    function testFuzz_deposit(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_CTF_BALANCE);

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), amount);
        assertEq(vault.totalAssets(), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdraw() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        // First deposit
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);

        uint256 ctfBefore = ctf.balanceOf(alice, POSITION_ID_YES);
        uint256 sharesBefore = vault.balanceOf(alice);

        vault.withdraw(withdrawAmount, alice, alice);

        uint256 ctfAfter = ctf.balanceOf(alice, POSITION_ID_YES);
        uint256 sharesAfter = vault.balanceOf(alice);

        vm.stopPrank();

        assertEq(ctfAfter - ctfBefore, withdrawAmount, "CTF not returned");
        assertEq(sharesBefore - sharesAfter, withdrawAmount, "Shares not burned");
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount);
    }

    function test_withdraw_full() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);
        vault.withdraw(depositAmount, alice, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(ctf.balanceOf(alice, POSITION_ID_YES), INITIAL_CTF_BALANCE);
    }

    function test_withdraw_toOther() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);

        // Withdraw to Bob
        vault.withdraw(withdrawAmount, alice, bob);
        vm.stopPrank();

        assertEq(ctf.balanceOf(bob, POSITION_ID_YES), INITIAL_CTF_BALANCE + withdrawAmount);
        assertEq(vault.balanceOf(alice), depositAmount - withdrawAmount);
    }

    function test_withdraw_withAllowance() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        // Alice deposits
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);

        // Alice approves Bob
        vault.approve(bob, withdrawAmount);
        vm.stopPrank();

        // Bob withdraws Alice's shares
        vm.prank(bob);
        vault.withdraw(withdrawAmount, alice, bob);

        assertEq(vault.balanceOf(alice), depositAmount - withdrawAmount);
        assertEq(ctf.balanceOf(bob, POSITION_ID_YES), INITIAL_CTF_BALANCE + withdrawAmount);
    }

    function test_revert_withdraw_insufficientShares() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);

        vm.expectRevert();
        vault.withdraw(depositAmount + 1, alice, alice);
        vm.stopPrank();
    }

    function test_revert_withdraw_noAllowance() public {
        uint256 depositAmount = 100e18;

        // Alice deposits
        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Bob tries to withdraw without allowance
        vm.prank(bob);
        vm.expectRevert();
        vault.withdraw(depositAmount, alice, bob);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC1155 RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_revert_receiveWrongPositionId() public {
        // Mint wrong position ID to alice
        uint256 wrongId = 999;
        ctf.mint(alice, wrongId, 100e18);

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);

        vm.expectRevert(PositionVault.PositionVault__InvalidPositionId.selector);
        ctf.safeTransferFrom(alice, address(vault), wrongId, 100e18, "");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_balanceOf() public {
        uint256 depositAmount = 100e18;

        assertEq(vault.balanceOf(alice), 0);

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), depositAmount);
    }

    function test_totalAssets() public {
        assertEq(vault.totalAssets(), 0);

        vm.startPrank(alice);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(100e18, alice);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 100e18);

        vm.startPrank(bob);
        ctf.setApprovalForAll(address(vault), true);
        vault.deposit(200e18, bob);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 300e18);
    }

    function test_asset() public view {
        assertEq(vault.asset(), address(ctf));
    }

    function test_balanceOfAssets() public view {
        // Returns user's CTF balance, not vault shares
        assertEq(vault.balanceOfAssets(alice), INITIAL_CTF_BALANCE);
    }
}
