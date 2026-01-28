// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPositionHolderFactory {
    function createPositionHolder(address _market) external returns (address);
}
