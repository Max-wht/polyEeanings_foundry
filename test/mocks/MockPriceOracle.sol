// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPriceOracle} from "../../src/Interface/IPriceOracle.sol";

/// @title MockPriceOracle
/// @notice Mock price oracle for testing
contract MockPriceOracle is IPriceOracle {
    mapping(address => uint256) public prices;

    function name() external pure returns (string memory) {
        return "MockPriceOracle";
    }

    function getQuote(uint256 inAmount, address base, address) external view returns (uint256 outAmount) {
        uint256 price = prices[base];
        if (price == 0) {
            price = 1e6; // Default: 1 position token = 1 USDC
        }
        // price is in USDC per 1e18 position tokens
        outAmount = (inAmount * price) / 1e18;
    }

    function getQuotes(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256 bidOutAmount, uint256 askOutAmount)
    {
        uint256 mid = this.getQuote(inAmount, base, quote);
        bidOutAmount = (mid * 99) / 100; // 1% spread
        askOutAmount = (mid * 101) / 100;
    }

    /// @notice Set price for testing
    /// @param vault The vault address
    /// @param price Price in USDC (6 decimals) per 1e18 position tokens
    function setPrice(address vault, uint256 price) external {
        prices[vault] = price;
    }
}
