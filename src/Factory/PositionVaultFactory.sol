// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPositionVaultFactory} from "../Interface/Factory/IPositionVaultFactory.sol";
import {PositionVault} from "../PositionVault.sol";

/// @title PositionVaultFactory
/// @notice Factory contract for creating PositionVault instances for Polymarket positions
/// @dev Each unique position ID gets its own vault that wraps the ERC1155 into ERC20
contract PositionVaultFactory is IPositionVaultFactory {
    /// @notice The Ethereum Vault Connector address
    address public immutable evc;
    /// @notice The Conditional Token Framework (Polymarket CTF) address
    address public immutable ctf;

    /// @notice Mapping from position ID to vault address
    mapping(uint256 positionId => address vault) public vaults;
    /// @notice Array of all created vaults
    address[] public allVaults;

    error PositionVaultFactory__VaultAlreadyExists();
    error PositionVaultFactory__InvalidAddress();

    constructor(address _evc, address _ctf) {
        if (_evc == address(0) || _ctf == address(0)) {
            revert PositionVaultFactory__InvalidAddress();
        }
        evc = _evc;
        ctf = _ctf;
    }

    /// @inheritdoc IPositionVaultFactory
    function createVault(uint256 positionId, string memory name, string memory symbol)
        external
        returns (address vault)
    {
        if (vaults[positionId] != address(0)) {
            revert PositionVaultFactory__VaultAlreadyExists();
        }

        vault = address(new PositionVault(ctf, evc, positionId, name, symbol));

        vaults[positionId] = vault;
        allVaults.push(vault);

        emit VaultCreated(positionId, ctf, vault, name, symbol);
    }

    /// @inheritdoc IPositionVaultFactory
    function getVault(uint256 positionId) external view returns (address) {
        return vaults[positionId];
    }

    /// @inheritdoc IPositionVaultFactory
    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }

    /// @notice Returns the total number of vaults created
    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}
