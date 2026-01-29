// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPositionVault {
    /// @notice Emitted when a user deposits Position tokens
    event PositionDeposited(address indexed user, uint256 indexed positionId, uint256 amount);
    /// @notice Emitted when a user withdraws Position tokens
    event PositionWithdrawn(address indexed user, uint256 indexed positionId, uint256 amount);

    /// @notice Deposit ERC1155 Position tokens and receive ERC20 shares
    /// @param assets The amount of Position tokens to deposit
    /// @param receiver The address to receive the shares
    /// @return shares The amount of shares minted (1:1 with assets)
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Withdraw ERC1155 Position tokens by burning shares
    /// @param assets The amount of Position tokens to withdraw
    /// @param owner The owner of the shares
    /// @param receiver The address to receive the Position tokens
    /// @return shares The amount of shares burned
    function withdraw(uint256 assets, address owner, address receiver) external returns (uint256 shares);

    /// @notice Returns the total Position tokens held by this vault
    function totalAssets() external view returns (uint256);

    /// @notice Returns the underlying market (ERC1155) address
    function asset() external view returns (address);

    /// @notice Returns the position ID this vault wraps
    function i_positionId() external view returns (uint256);

    /// @notice Returns the market (CTF) contract address
    function i_market() external view returns (address);

    /// @notice Returns the factory that created this vault
    function i_factory() external view returns (address);

    /// @notice Returns the EVC address used by this vault
    function EVC() external view returns (address);

    /// @notice Returns the ERC20 balance of an owner (used by Euler as collateral balance)
    function balanceOf(address owner) external view returns (uint256);

    /// @notice Returns the Position token balance of an owner in the underlying market
    function balanceOfAssets(address owner) external view returns (uint256);
}
