// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseTest} from "../Base.t.sol";
import {PositionVault} from "../../src/PositionVault.sol";
import {PositionVaultFactory} from "../../src/Factory/PositionVaultFactory.sol";
import {IPositionVaultFactory} from "../../src/Interface/Factory/IPositionVaultFactory.sol";

/// @title PositionVaultFactoryTest
/// @notice Unit tests for PositionVaultFactory contract
contract PositionVaultFactoryTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(factory.evc(), address(evc));
        assertEq(factory.ctf(), address(ctf));
        assertEq(factory.getVaultCount(), 0);
    }

    function test_revert_deployment_invalidEvc() public {
        vm.expectRevert(PositionVaultFactory.PositionVaultFactory__InvalidAddress.selector);
        new PositionVaultFactory(address(0), address(ctf));
    }

    function test_revert_deployment_invalidCtf() public {
        vm.expectRevert(PositionVaultFactory.PositionVaultFactory__InvalidAddress.selector);
        new PositionVaultFactory(address(evc), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          CREATE VAULT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createVault() public {
        vm.prank(deployer);
        address vault = factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES");

        assertTrue(vault != address(0));
        assertEq(factory.getVault(POSITION_ID_YES), vault);
        assertEq(factory.getVaultCount(), 1);

        // Check vault properties
        PositionVault pv = PositionVault(vault);
        assertEq(pv.name(), "PolyLend YES");
        assertEq(pv.symbol(), "pYES");
        assertEq(pv.i_positionId(), POSITION_ID_YES);
        assertEq(address(pv.i_market()), address(ctf));
    }

    function test_createVault_emitsEvent() public {
        // Only check indexed params (positionId, market), not the vault address since it's computed at deploy time
        vm.expectEmit(true, true, false, false);
        emit IPositionVaultFactory.VaultCreated(POSITION_ID_YES, address(ctf), address(0), "", "");

        vm.prank(deployer);
        factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES");
    }

    function test_createVault_multiple() public {
        vm.startPrank(deployer);

        address vault1 = factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES");
        address vault2 = factory.createVault(POSITION_ID_NO, "PolyLend NO", "pNO");

        vm.stopPrank();

        assertTrue(vault1 != vault2);
        assertEq(factory.getVault(POSITION_ID_YES), vault1);
        assertEq(factory.getVault(POSITION_ID_NO), vault2);
        assertEq(factory.getVaultCount(), 2);

        address[] memory allVaults = factory.getAllVaults();
        assertEq(allVaults.length, 2);
        assertEq(allVaults[0], vault1);
        assertEq(allVaults[1], vault2);
    }

    function test_revert_createVault_duplicate() public {
        vm.startPrank(deployer);

        factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES");

        vm.expectRevert(PositionVaultFactory.PositionVaultFactory__VaultAlreadyExists.selector);
        factory.createVault(POSITION_ID_YES, "PolyLend YES 2", "pYES2");

        vm.stopPrank();
    }

    function test_createVault_anyoneCanCreate() public {
        // Anyone can create vaults
        vm.prank(alice);
        address vault = factory.createVault(POSITION_ID_YES, "PolyLend YES", "pYES");

        assertTrue(vault != address(0));
    }

    function testFuzz_createVault(uint256 positionId, string memory name, string memory symbol) public {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);

        vm.prank(deployer);
        address vault = factory.createVault(positionId, name, symbol);

        assertTrue(vault != address(0));
        assertEq(factory.getVault(positionId), vault);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getVault_notCreated() public view {
        assertEq(factory.getVault(999), address(0));
    }

    function test_getAllVaults_empty() public view {
        address[] memory vaults = factory.getAllVaults();
        assertEq(vaults.length, 0);
    }

    function test_getVaultCount() public {
        assertEq(factory.getVaultCount(), 0);

        vm.startPrank(deployer);
        factory.createVault(1, "V1", "V1");
        assertEq(factory.getVaultCount(), 1);

        factory.createVault(2, "V2", "V2");
        assertEq(factory.getVaultCount(), 2);

        factory.createVault(3, "V3", "V3");
        assertEq(factory.getVaultCount(), 3);
        vm.stopPrank();
    }
}
