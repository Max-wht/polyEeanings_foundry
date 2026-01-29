// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPositionVaultFactory {
    /// @notice Emitted when a new PositionVault is created
    event VaultCreated(
        uint256 indexed positionId, address indexed market, address vault, string name, string symbol
    );

    /// @notice Creates a new PositionVault for a specific Polymarket position
    /// @param positionId The ERC1155 token ID representing the position
    /// @param name The name for the ERC20 wrapper token
    /// @param symbol The symbol for the ERC20 wrapper token
    /// @return vault The address of the newly created PositionVault
    function createVault(uint256 positionId, string memory name, string memory symbol)
        external
        returns (address vault);

    /// @notice Returns the vault address for a specific position ID
    /// @param positionId The ERC1155 token ID
    /// @return The vault address, or address(0) if not created
    function getVault(uint256 positionId) external view returns (address);

    /// @notice Returns the EVC address used by created vaults
    function evc() external view returns (address);

    /// @notice Returns the CTF (Conditional Token Framework) address
    function ctf() external view returns (address);

    /// @notice Returns all created vault addresses
    function getAllVaults() external view returns (address[] memory);
}
