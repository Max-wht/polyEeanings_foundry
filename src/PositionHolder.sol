// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract PositionHolder {
    address public owner;

    constructor() {
        owner = msg.sender;
    }
}
