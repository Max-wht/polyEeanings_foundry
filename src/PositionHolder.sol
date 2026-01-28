// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IPositionHolderFactory} from "./Interface/Factory/IPositionHolderFactory.sol";
import {EVCUtil} from "@ethereum-vault-connector/utils/EVCUtil.sol";

contract PositionHolder is ERC1155Holder, EVCUtil {
    IPositionHolderFactory public immutable i_factory;
    IERC1155 public immutable i_market;

    /*//////////////////////////////////////////////////////////////
                                 SLOTS
    //////////////////////////////////////////////////////////////*/
    mapping(address user => mapping(uint256 positionId => uint256 amount)) public mappingPositions;

    /*//////////////////////////////////////////////////////////////
                                 EVENT
    //////////////////////////////////////////////////////////////*/
    event PositionDeposited(address user, uint256 positionId, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERROR
    //////////////////////////////////////////////////////////////*/
    error PositionHolder__NotMarket();

    /*//////////////////////////////////////////////////////////////
                                  INIT
    //////////////////////////////////////////////////////////////*/
    constructor(address _market, address _evc) EVCUtil(_evc) {
        i_factory = IPositionHolderFactory(msg.sender);
        i_market = IERC1155(_market);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
    ///@dev deposit the position to the position holder
    function deposit(address from) external {}

    ///@dev withdraw the position from the position holder, and check the account status in Euler
    function withdraw(address from) external {
        //code above
        evc.requireAccountStatus(from);
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC FUNCTION
    //////////////////////////////////////////////////////////////*/
    ///@dev Euler use this function to get the total value of the position
    function balanceOf(address) public view returns (uint256 totalValue) {}

    /// @dev the override function for the ERC1155Receiver interface
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes memory data)
        public
        virtual
        override
        returns (bytes4)
    {
        if (msg.sender != address(i_market)) {
            revert PositionHolder__NotMarket();
        }
        mappingPositions[from][id] += value;
        emit PositionDeposited(from, id, value);
        return super.onERC1155Received(operator, from, id, value, data);
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (msg.sender != address(i_market)) {
            revert PositionHolder__NotMarket();
        }
        //@audit-DOS
        for (uint256 i = 0; i < ids.length; i++) {
            mappingPositions[from][ids[i]] += values[i];
            emit PositionDeposited(from, ids[i], values[i]);
        }
        return super.onERC1155BatchReceived(operator, from, ids, values, data);
    }
}
