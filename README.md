# Hybrid Governor DAO

A robust, upgradeable **Decentralized Autonomous Organization (DAO)** built with **Solidity** and **OpenZeppelin v5**.  
This system implements a **hybrid governance model**, supporting both **on-chain voting** and **off-chain vote result submission**, managed via a **UUPS-upgradeable Governor** contract.

---

## Table of Contents
- Architecture
- Core Contracts
- Prerequisites
- Installation
- Testing
- Deployment
- Configuration
- License

---

## Architecture

Token (ERC20Votes) → Governor (UUPS Proxy) → Timelock → Treasury

---

## Core Contracts

- **GOVToken.sol** – ERC20Votes governance token
- **DAOTimelock.sol** – TimelockController executor
- **DAOGovernor.sol** – Upgradeable hybrid Governor
- **Treasury.sol** – Secure DAO vault

---

## Prerequisites

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

## Installation

```bash
git clone https://github.com/SudheerKondamuri/hybrid-governor-dao
cd hybrid-governor-dao
forge install
forge build
```

---

## Testing

```bash
forge test
forge coverage --ir-minimum
```

---

## Deployment

```bash
forge script scripts/Deploy.s.sol:DeployDAO --rpc-url <RPC> --broadcast
```

---

## Configuration
- Optimizer: 200 runs
- via_ir = true

---

## License
MIT
