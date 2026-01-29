// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {EthereumVaultConnector} from "@ethereum-vault-connector/EthereumVaultConnector.sol";

import {PositionVaultFactory} from "../src/Factory/PositionVaultFactory.sol";
import {PolymarketOracle} from "../src/Oracle/PolymarketOracle.sol";
import {PositionRouter} from "../src/PositionRouter.sol";

/// @title DeployTestnet
/// @notice Deploy PolyLend to Polygon Amoy testnet with mock CTF
/// @dev Usage:
///      1. Set environment variables:
///         export PRIVATE_KEY=your_private_key
///         export POLYGON_AMOY_RPC_URL=https://rpc-amoy.polygon.technology
///      2. Run:
///         forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url $POLYGON_AMOY_RPC_URL --broadcast --verify
contract DeployTestnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== Deploying to Polygon Amoy Testnet ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy Mock CTF (ERC1155)
        MockCTF ctf = new MockCTF("https://polymarket.com/api/token/");
        console2.log("[1/5] MockCTF deployed:", address(ctf));

        // Step 2: Deploy EVC
        EthereumVaultConnector evc = new EthereumVaultConnector();
        console2.log("[2/5] EVC deployed:", address(evc));

        // Step 3: Deploy Factory
        PositionVaultFactory factory = new PositionVaultFactory(address(evc), address(ctf));
        console2.log("[3/5] Factory deployed:", address(factory));

        // Step 4: Deploy Oracle
        PolymarketOracle oracle = new PolymarketOracle(deployer);
        console2.log("[4/5] Oracle deployed:", address(oracle));

        // Step 5: Deploy Router
        PositionRouter router = new PositionRouter(address(evc), address(factory));
        console2.log("[5/5] Router deployed:", address(router));

        // Setup: Create example vaults for testing
        console2.log("\n=== Setting up example vaults ===");

        // Example: "Will Trump win 2024?" YES/NO positions
        uint256 yesPositionId = 12345;
        uint256 noPositionId = 12346;

        address yesVault = factory.createVault(yesPositionId, "Trump 2024 YES", "pTRUMP-YES");
        address noVault = factory.createVault(noPositionId, "Trump 2024 NO", "pTRUMP-NO");

        console2.log("YES Vault created:", yesVault);
        console2.log("NO Vault created:", noVault);

        // Set oracle prices (60% YES, 40% NO)
        oracle.setPrice(yesVault, 0.6e6); // 0.6 USDC
        oracle.setPrice(noVault, 0.4e6); // 0.4 USDC

        console2.log("Oracle prices set");

        // Mint test tokens to deployer
        ctf.mint(deployer, yesPositionId, 10000e18);
        ctf.mint(deployer, noPositionId, 10000e18);
        console2.log("Minted 10,000 position tokens to deployer");

        vm.stopBroadcast();

        // Output deployment summary
        console2.log("\n========================================");
        console2.log("       DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("Network: Polygon Amoy Testnet");
        console2.log("----------------------------------------");
        console2.log("MockCTF:          ", address(ctf));
        console2.log("EVC:              ", address(evc));
        console2.log("Factory:          ", address(factory));
        console2.log("Oracle:           ", address(oracle));
        console2.log("Router:           ", address(router));
        console2.log("----------------------------------------");
        console2.log("YES Vault:        ", yesVault);
        console2.log("NO Vault:         ", noVault);
        console2.log("YES Position ID:  ", yesPositionId);
        console2.log("NO Position ID:   ", noPositionId);
        console2.log("========================================\n");

        // Output for .env file
        console2.log("Add to your .env file:");
        console2.log("----------------------------------------");
        console2.log("MOCK_CTF_ADDRESS=", address(ctf));
        console2.log("EVC_ADDRESS=", address(evc));
        console2.log("FACTORY_ADDRESS=", address(factory));
        console2.log("ORACLE_ADDRESS=", address(oracle));
        console2.log("ROUTER_ADDRESS=", address(router));
    }
}

/// @title MockCTF
/// @notice Mock Conditional Token Framework for testnet
/// @dev Simulates Polymarket's ERC1155 position tokens
contract MockCTF {
    string public baseURI;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value
    );
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    constructor(string memory _baseURI) {
        baseURI = _baseURI;
    }

    function uri(uint256 id) public view returns (string memory) {
        return string(abi.encodePacked(baseURI, _toString(id)));
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view returns (uint256[] memory) {
        require(accounts.length == ids.length, "Length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not approved");
        require(to != address(0), "Transfer to zero");
        require(_balances[id][from] >= amount, "Insufficient balance");

        _balances[id][from] -= amount;
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not approved");
        require(to != address(0), "Transfer to zero");
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            require(_balances[ids[i]][from] >= amounts[i], "Insufficient balance");
            _balances[ids[i]][from] -= amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    // ============ Testing Functions ============

    function mint(address to, uint256 id, uint256 amount) external {
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        require(ids.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(_balances[id][from] >= amount, "Insufficient balance");
        _balances[id][from] -= amount;
        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    // ============ Internal Functions ============

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("Rejected");
                }
            } catch {
                revert("Non-receiver");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response)
            {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("Rejected");
                }
            } catch {
                revert("Non-receiver");
            }
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0xd9b67a26; // ERC1155
    }
}

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4);
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}
