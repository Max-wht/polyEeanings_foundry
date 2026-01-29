// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IPriceOracle
/// @notice Euler-compatible price oracle interface
/// @dev Implements the standard Euler IPriceOracle interface for integration with EVault
interface IPriceOracle {
    /// @notice Get the name of the oracle
    /// @return The name of the oracle
    function name() external view returns (string memory);

    /// @notice One-sided price: How much quote token you would get for inAmount of base token
    /// @param inAmount The amount of base token to convert
    /// @param base The token that is being priced (PositionVault address)
    /// @param quote The token that is the unit of account (e.g., USDC)
    /// @return outAmount The amount of quote equivalent to inAmount of base
    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256 outAmount);

    /// @notice Two-sided price: bid and ask prices
    /// @param inAmount The amount of base token to convert
    /// @param base The token that is being priced
    /// @param quote The token that is the unit of account
    /// @return bidOutAmount The amount of quote you would get for selling inAmount of base
    /// @return askOutAmount The amount of quote you would spend for buying inAmount of base
    function getQuotes(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256 bidOutAmount, uint256 askOutAmount);
}
