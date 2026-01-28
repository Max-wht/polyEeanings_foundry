// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract PositionHolder {
    address public immutable factory;
    address public immutable market;

    /*//////////////////////////////////////////////////////////////
                                 SLOTS
    //////////////////////////////////////////////////////////////*/
    mapping(address user => mapping( address position => uint256 amount)) public mappingPositions;

    /*//////////////////////////////////////////////////////////////
                                  INIT
    //////////////////////////////////////////////////////////////*/
    constructor() {
        factory = msg.sender;
    }

    function initialize() external {}
}
