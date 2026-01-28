# PolyLend Protocol

> 基于 Polymarket Position 的借贷协议 - 将预测市场头寸作为抵押品释放流动性

## 目录

- [项目概述](#项目概述)
- [依赖库](#依赖库)
- [系统架构](#系统架构)
- [合约模块](#合约模块)
  - [Module 1: Interfaces (自定义)](#module-1-interfaces-自定义)
  - [Module 2: Libraries](#module-2-libraries)
  - [Module 3: Oracle](#module-3-oracle)
  - [Module 4: Core](#module-4-core)
  - [Module 5: Euler Integration](#module-5-euler-integration)
- [开发路线图](#开发路线图)
- [安全考虑](#安全考虑)

---

## 项目概述

### 背景

用户在 Polymarket 持有的预测市场头寸（Conditional Tokens）在市场结算前无法进一步利用其价值。PolyLend 协议允许用户将这些头寸作为抵押品借出稳定币，释放资金流动性。

### 核心功能

1. **Position 包装**: 将 Polymarket CTF (ERC1155) 包装成 ERC6909
2. **流动性门槛**: 仅允许高流动性市场的头寸作为抵押品
3. **借贷集成**: 与 Euler Protocol 集成实现借贷功能
4. **清算机制**: 处理头寸价值下跌或市场结算的清算场景

### 技术栈

- Solidity ^0.8.24
- Foundry (开发框架)
- OpenZeppelin Contracts 5.x (ERC6909, 访问控制, 安全工具)
- Gnosis Conditional Tokens (Polymarket CTF 基础)
- Euler Vault Kit (借贷基础设施)
