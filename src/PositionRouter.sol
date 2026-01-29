// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEVC} from "@ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IPositionVault} from "./Interface/IPositionVault.sol";
import {IPositionVaultFactory} from "./Interface/Factory/IPositionVaultFactory.sol";

/// @title IEVault
/// @notice Minimal interface for Euler Vault borrow/repay operations
interface IEVault {
    function borrow(uint256 amount, address receiver) external returns (uint256);
    function repay(uint256 amount, address receiver) external returns (uint256);
    function debtOf(address account) external view returns (uint256);
    function asset() external view returns (address);
}

/// @title PositionRouter
/// @notice Router contract for simplified interaction with PolyLend protocol
/// @dev Aggregates multiple operations (deposit, borrow, repay, withdraw) into single transactions
contract PositionRouter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Ethereum Vault Connector
    IEVC public immutable evc;
    /// @notice The PositionVault factory
    IPositionVaultFactory public immutable factory;
    /// @notice The Polymarket CTF (ERC1155)
    IERC1155 public immutable ctf;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DepositAndBorrow(
        address indexed user, address indexed positionVault, uint256 depositAmount, uint256 borrowAmount
    );
    event RepayAndWithdraw(
        address indexed user, address indexed positionVault, uint256 repayAmount, uint256 withdrawAmount
    );
    event Deposit(address indexed user, address indexed positionVault, uint256 amount);
    event Withdraw(address indexed user, address indexed positionVault, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PositionRouter__VaultNotFound();
    error PositionRouter__InvalidAmount();
    error PositionRouter__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _evc, address _factory) {
        evc = IEVC(_evc);
        factory = IPositionVaultFactory(_factory);
        ctf = IERC1155(factory.ctf());
    }

    /*//////////////////////////////////////////////////////////////
                           MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit Position tokens and borrow from Euler in one transaction
    /// @param positionId The Polymarket position ID (ERC1155 token ID)
    /// @param depositAmount Amount of position tokens to deposit
    /// @param borrowVault The Euler vault to borrow from (e.g., USDC vault)
    /// @param borrowAmount Amount to borrow from the Euler vault
    /// @dev User must approve this router for the CTF ERC1155 tokens first
    function depositAndBorrow(uint256 positionId, uint256 depositAmount, address borrowVault, uint256 borrowAmount)
        external
    {
        if (depositAmount == 0) revert PositionRouter__InvalidAmount();

        address positionVault = factory.getVault(positionId);
        if (positionVault == address(0)) revert PositionRouter__VaultNotFound();

        address user = msg.sender;

        // 1. Transfer ERC1155 from user to this contract
        ctf.safeTransferFrom(user, address(this), positionId, depositAmount, "");

        // 2. Approve PositionVault to take the tokens
        ctf.setApprovalForAll(positionVault, true);

        // 3. Deposit into PositionVault, shares go to user
        IPositionVault(positionVault).deposit(depositAmount, user);

        // 4. Use EVC batch to enable collateral, enable controller, and borrow
        if (borrowAmount > 0) {
            IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);

            // Enable PositionVault as collateral
            items[0] = IEVC.BatchItem({
                targetContract: address(evc),
                onBehalfOfAccount: address(0),
                value: 0,
                data: abi.encodeCall(IEVC.enableCollateral, (user, positionVault))
            });

            // Enable borrow vault as controller
            items[1] = IEVC.BatchItem({
                targetContract: address(evc),
                onBehalfOfAccount: address(0),
                value: 0,
                data: abi.encodeCall(IEVC.enableController, (user, borrowVault))
            });

            // Borrow - this needs to be called through EVC.call
            items[2] = IEVC.BatchItem({
                targetContract: borrowVault,
                onBehalfOfAccount: user,
                value: 0,
                data: abi.encodeCall(IEVault.borrow, (borrowAmount, user))
            });

            evc.batch(items);
        }

        emit DepositAndBorrow(user, positionVault, depositAmount, borrowAmount);
    }

    /// @notice Repay debt and withdraw Position tokens in one transaction
    /// @param positionId The Polymarket position ID
    /// @param repayVault The Euler vault to repay to
    /// @param repayAmount Amount to repay (use type(uint256).max for full debt)
    /// @param withdrawAmount Amount of position tokens to withdraw
    /// @dev User must approve this router for the repay asset (e.g., USDC) first
    /// @dev User must approve this router for PositionVault shares if withdrawing
    function repayAndWithdraw(uint256 positionId, address repayVault, uint256 repayAmount, uint256 withdrawAmount)
        external
    {
        address positionVault = factory.getVault(positionId);
        if (positionVault == address(0)) revert PositionRouter__VaultNotFound();

        address user = msg.sender;

        // 1. Repay debt if requested
        if (repayAmount > 0) {
            address repayAsset = IEVault(repayVault).asset();

            // Handle max repay
            uint256 actualRepayAmount = repayAmount;
            if (repayAmount == type(uint256).max) {
                actualRepayAmount = IEVault(repayVault).debtOf(user);
            }

            // Transfer repay asset from user
            IERC20(repayAsset).safeTransferFrom(user, address(this), actualRepayAmount);

            // Approve vault to take the tokens
            IERC20(repayAsset).forceApprove(repayVault, actualRepayAmount);

            // Repay through EVC
            evc.call(repayVault, user, 0, abi.encodeCall(IEVault.repay, (actualRepayAmount, user)));
        }

        // 2. Withdraw position tokens if requested
        if (withdrawAmount > 0) {
            // User needs to have approved this router for their PositionVault shares
            // We transfer shares to this contract first, then withdraw
            IERC20(positionVault).safeTransferFrom(user, address(this), withdrawAmount);

            // Withdraw - sends ERC1155 to user
            IPositionVault(positionVault).withdraw(withdrawAmount, address(this), user);
        }

        emit RepayAndWithdraw(user, positionVault, repayAmount, withdrawAmount);
    }

    /// @notice Deposit Position tokens only (no borrowing)
    /// @param positionId The Polymarket position ID
    /// @param amount Amount of position tokens to deposit
    /// @param enableAsCollateral Whether to enable the vault as collateral
    function depositOnly(uint256 positionId, uint256 amount, bool enableAsCollateral) external {
        if (amount == 0) revert PositionRouter__InvalidAmount();

        address positionVault = factory.getVault(positionId);
        if (positionVault == address(0)) revert PositionRouter__VaultNotFound();

        address user = msg.sender;

        // Transfer and deposit
        ctf.safeTransferFrom(user, address(this), positionId, amount, "");
        ctf.setApprovalForAll(positionVault, true);
        IPositionVault(positionVault).deposit(amount, user);

        // Optionally enable as collateral
        if (enableAsCollateral) {
            evc.enableCollateral(user, positionVault);
        }

        emit Deposit(user, positionVault, amount);
    }

    /// @notice Withdraw Position tokens only
    /// @param positionId The Polymarket position ID
    /// @param amount Amount to withdraw
    function withdrawOnly(uint256 positionId, uint256 amount) external {
        if (amount == 0) revert PositionRouter__InvalidAmount();

        address positionVault = factory.getVault(positionId);
        if (positionVault == address(0)) revert PositionRouter__VaultNotFound();

        address user = msg.sender;

        // Transfer shares to this contract
        IERC20(positionVault).safeTransferFrom(user, address(this), amount);

        // Withdraw to user
        IPositionVault(positionVault).withdraw(amount, address(this), user);

        emit Withdraw(user, positionVault, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the vault address for a position ID
    /// @param positionId The Polymarket position ID
    /// @return The vault address
    function getVault(uint256 positionId) external view returns (address) {
        return factory.getVault(positionId);
    }

    /// @notice Check user's position vault share balance
    /// @param positionId The Polymarket position ID
    /// @param user The user address
    /// @return The share balance
    function getUserShares(uint256 positionId, address user) external view returns (uint256) {
        address vault = factory.getVault(positionId);
        if (vault == address(0)) return 0;
        return IERC20(vault).balanceOf(user);
    }

    /// @notice Check user's debt in a borrow vault
    /// @param borrowVault The Euler vault address
    /// @param user The user address
    /// @return The debt amount
    function getUserDebt(address borrowVault, address user) external view returns (uint256) {
        return IEVault(borrowVault).debtOf(user);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC1155 RECEIVER
    //////////////////////////////////////////////////////////////*/

    /// @notice Handle ERC1155 token receipt
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// @notice Handle ERC1155 batch token receipt
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}
