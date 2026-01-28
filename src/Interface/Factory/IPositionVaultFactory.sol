// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPositionVaultFactory {
    function createPositionVault(address _market) external returns (address);
}
