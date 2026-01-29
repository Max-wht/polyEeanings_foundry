// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPriceOracle} from "../Interface/IPriceOracle.sol";
import {IPositionVault} from "../Interface/IPositionVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PolymarketOracle
/// @notice Oracle contract providing prices for Polymarket Position Vaults
/// @dev Implements Euler's IPriceOracle interface for integration with EVault
/// @dev This is a simplified admin-controlled oracle. In production, use Chainlink or UMA.
contract PolymarketOracle is IPriceOracle, Ownable {
    /// @notice Price data for a position vault
    struct PriceData {
        uint256 price; // Price in 18 decimals (1e18 = 1 USDC per position token)
        uint256 lastUpdated; // Timestamp of last update
        bool isValid; // Whether the price is valid/active
    }

    /// @notice Mapping from vault address to price data
    mapping(address vault => PriceData) public prices;

    /// @notice Mapping from vault to bid/ask spread (in basis points, 100 = 1%)
    mapping(address vault => uint256 spreadBps) public spreads;

    /// @notice Default spread in basis points (2% = 200 bps)
    uint256 public defaultSpreadBps = 200;

    /// @notice Maximum allowed price staleness (default: 1 day)
    uint256 public maxStaleness = 1 days;

    /// @notice USDC decimals (6)
    uint8 public constant USDC_DECIMALS = 6;
    /// @notice Position token decimals (18, same as ERC20 shares)
    uint8 public constant POSITION_DECIMALS = 18;
    /// @notice Price precision (18 decimals)
    uint256 public constant PRICE_PRECISION = 1e18;

    event PriceUpdated(address indexed vault, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event SpreadUpdated(address indexed vault, uint256 oldSpread, uint256 newSpread);
    event DefaultSpreadUpdated(uint256 oldSpread, uint256 newSpread);
    event MaxStalenessUpdated(uint256 oldStaleness, uint256 newStaleness);
    event PriceInvalidated(address indexed vault);

    error PolymarketOracle__PriceNotSet();
    error PolymarketOracle__StalePrice();
    error PolymarketOracle__InvalidPrice();
    error PolymarketOracle__UnsupportedQuote();
    error PolymarketOracle__InvalidSpread();

    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc IPriceOracle
    function name() external pure returns (string memory) {
        return "PolymarketOracle";
    }

    /// @inheritdoc IPriceOracle
    /// @dev Converts position vault shares to USDC equivalent value
    /// @dev Price is stored as: how many USDC (in 6 decimals) for 1e18 position tokens
    function getQuote(uint256 inAmount, address base, address quote) public view returns (uint256 outAmount) {
        PriceData memory priceData = prices[base];

        if (!priceData.isValid) {
            revert PolymarketOracle__PriceNotSet();
        }

        if (block.timestamp - priceData.lastUpdated > maxStaleness) {
            revert PolymarketOracle__StalePrice();
        }

        // price is in 18 decimals: price of 1e18 position tokens in USDC
        // inAmount is in 18 decimals (ERC20 shares)
        // outAmount should be in USDC decimals (6)
        // Formula: outAmount = inAmount * price / PRICE_PRECISION
        // This gives us USDC with 6 decimals
        outAmount = (inAmount * priceData.price) / PRICE_PRECISION;
    }

    /// @inheritdoc IPriceOracle
    function getQuotes(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256 bidOutAmount, uint256 askOutAmount)
    {
        uint256 midPrice = getQuote(inAmount, base, quote);
        uint256 spread = spreads[base] > 0 ? spreads[base] : defaultSpreadBps;

        // Bid = what you get for selling (mid - spread/2)
        // Ask = what you pay for buying (mid + spread/2)
        bidOutAmount = midPrice - (midPrice * spread) / 20000; // spread/2 in bps
        askOutAmount = midPrice + (midPrice * spread) / 20000;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the price for a position vault
    /// @param vault The position vault address
    /// @param price The price in 18 decimals (amount of USDC for 1e18 position tokens)
    /// @dev For a position trading at $0.60, set price = 0.6e6 (0.6 USDC)
    function setPrice(address vault, uint256 price) external onlyOwner {
        if (price == 0) {
            revert PolymarketOracle__InvalidPrice();
        }

        uint256 oldPrice = prices[vault].price;
        prices[vault] = PriceData({price: price, lastUpdated: block.timestamp, isValid: true});

        emit PriceUpdated(vault, oldPrice, price, block.timestamp);
    }

    /// @notice Batch set prices for multiple vaults
    /// @param vaults Array of vault addresses
    /// @param _prices Array of prices
    function setPrices(address[] calldata vaults, uint256[] calldata _prices) external onlyOwner {
        require(vaults.length == _prices.length, "Length mismatch");

        for (uint256 i = 0; i < vaults.length; i++) {
            if (_prices[i] == 0) {
                revert PolymarketOracle__InvalidPrice();
            }

            uint256 oldPrice = prices[vaults[i]].price;
            prices[vaults[i]] = PriceData({price: _prices[i], lastUpdated: block.timestamp, isValid: true});

            emit PriceUpdated(vaults[i], oldPrice, _prices[i], block.timestamp);
        }
    }

    /// @notice Invalidate the price for a vault (e.g., market settled)
    /// @param vault The position vault address
    function invalidatePrice(address vault) external onlyOwner {
        prices[vault].isValid = false;
        emit PriceInvalidated(vault);
    }

    /// @notice Set the spread for a specific vault
    /// @param vault The position vault address
    /// @param spreadBps Spread in basis points (100 = 1%)
    function setSpread(address vault, uint256 spreadBps) external onlyOwner {
        if (spreadBps > 5000) {
            // Max 50%
            revert PolymarketOracle__InvalidSpread();
        }

        uint256 oldSpread = spreads[vault];
        spreads[vault] = spreadBps;

        emit SpreadUpdated(vault, oldSpread, spreadBps);
    }

    /// @notice Set the default spread for vaults without custom spread
    /// @param spreadBps Default spread in basis points
    function setDefaultSpread(uint256 spreadBps) external onlyOwner {
        if (spreadBps > 5000) {
            revert PolymarketOracle__InvalidSpread();
        }

        uint256 oldSpread = defaultSpreadBps;
        defaultSpreadBps = spreadBps;

        emit DefaultSpreadUpdated(oldSpread, spreadBps);
    }

    /// @notice Set the maximum allowed price staleness
    /// @param _maxStaleness Maximum staleness in seconds
    function setMaxStaleness(uint256 _maxStaleness) external onlyOwner {
        uint256 oldStaleness = maxStaleness;
        maxStaleness = _maxStaleness;

        emit MaxStalenessUpdated(oldStaleness, _maxStaleness);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current price data for a vault
    /// @param vault The position vault address
    /// @return price The current price
    /// @return lastUpdated Timestamp of last update
    /// @return isValid Whether the price is valid
    function getPriceData(address vault) external view returns (uint256 price, uint256 lastUpdated, bool isValid) {
        PriceData memory data = prices[vault];
        return (data.price, data.lastUpdated, data.isValid);
    }

    /// @notice Check if a vault's price is fresh (not stale)
    /// @param vault The position vault address
    /// @return True if the price is fresh and valid
    function isPriceFresh(address vault) external view returns (bool) {
        PriceData memory data = prices[vault];
        return data.isValid && (block.timestamp - data.lastUpdated <= maxStaleness);
    }
}
