// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title MockERC1155
/// @notice Mock ERC1155 token for testing (simulates Polymarket CTF)
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    /// @notice Mint tokens for testing
    /// @param to Recipient address
    /// @param id Token ID (position ID)
    /// @param amount Amount to mint
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    /// @notice Batch mint tokens for testing
    /// @param to Recipient address
    /// @param ids Token IDs
    /// @param amounts Amounts to mint
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        _mintBatch(to, ids, amounts, "");
    }

    /// @notice Burn tokens for testing
    /// @param from Owner address
    /// @param id Token ID
    /// @param amount Amount to burn
    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }
}
