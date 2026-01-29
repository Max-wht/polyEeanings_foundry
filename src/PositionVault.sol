// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IPositionVaultFactory} from "./Interface/Factory/IPositionVaultFactory.sol";
import {EVCUtil} from "@ethereum-vault-connector/utils/EVCUtil.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract PositionVault is ERC20, ERC1155Holder, EVCUtil {
    IPositionVaultFactory public immutable i_factory;
    IERC1155 public immutable i_market;
    uint256 public immutable i_positionId;

    event PositionDeposited(address user, uint256 positionId, uint256 amount);
    event PositionWithdrawn(address user, uint256 positionId, uint256 amount);

    error PositionVault__InvalidPositionId();
    error PositionVault__NoMarket();

    constructor(address _market, address _evc, uint256 _positionId, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        EVCUtil(_evc)
    {
        i_factory = IPositionVaultFactory(msg.sender);
        i_market = IERC1155(_market);
        i_positionId = _positionId;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = assets; // 1:1
        _mint(receiver, shares);

        emit PositionDeposited(receiver, i_positionId, assets);

        i_market.safeTransferFrom(_msgSender(), address(this), i_positionId, assets, "");
    }

    ///@dev owner withdraws. receiver receives the CTF
    function withdraw(uint256 assets, address owner, address receiver) external returns (uint256 shares) {
        shares = assets; // 1:1
        address sender = _msgSender();
        if (sender != owner) {
            _spendAllowance(owner, sender, shares);
        }
        _burn(owner, shares);

        emit PositionWithdrawn(receiver, i_positionId, assets);

        i_market.safeTransferFrom(address(this), receiver, i_positionId, assets, "");

        evc.requireAccountStatusCheck(owner);
    }

    ///@dev Returns the shares balance of the owner (used by Euler as collateral balance)
    function balanceOf(address owner) public view override returns (uint256) {
        return super.balanceOf(owner);
    }

    function balanceOfAssets(address owner) public view returns (uint256) {
        return i_market.balanceOf(owner, i_positionId);
    }

    function _msgSender() internal view override(Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }

    function onERC1155Received(address, address, uint256 id, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        if (id != i_positionId) {
            revert PositionVault__InvalidPositionId();
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory ids, uint256[] memory, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        if (ids.length != 1 || ids[0] != i_positionId) {
            revert PositionVault__InvalidPositionId();
        }
        return this.onERC1155BatchReceived.selector;
    }

    function totalAssets() public view returns (uint256) {
        return i_market.balanceOf(address(this), i_positionId);
    }

    function asset() public view returns (address) {
        return address(i_market);
    }
}
