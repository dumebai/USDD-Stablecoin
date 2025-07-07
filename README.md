# USDD Stablecoin Protocol

> Algorithmic, Overcollateralized Stablecoin pegged to $1, backed by wETH/wBTC. Built with Solidity & Foundry.

## ⚙️ Overview

USDD is a decentralized stablecoin protocol inspired by DAI, designed to maintain a **1:1 USD peg** through **overcollateralization** using exogenous assets like wETH and wBTC. It is governed algorithmically, with **no fees, no governance tokens**, and **liquidation incentives** built-in.

- 💰 **Pegged to USD**
- 🔒 **Overcollateralized (min 200%)**
- 🧠 **Algorithmic logic, no manual governance**
- 💥 **Supports liquidation with bonuses**
- ⚡ **Powered by Chainlink Oracles**

---

## 📁 Contracts Layout

### `USDDToken.sol`
- ERC20 stablecoin (`USDD`)
- Mintable and burnable by `USDDEngine` (owner)
- Anchored to $1 via logic in `USDDEngine`

### `USDDEngine.sol`
- Core engine for minting/burning USDD
- Handles collateral deposit, redemption, and liquidation
- Enforces Health Factor ≥ 1 (i.e., ≥200% collateralization)
- Uses Chainlink oracles for real-time price feeds

### `USDDEngineErrors.sol`
- Custom error declarations for gas-efficient reverts

---

## 🧪 Getting Started (with Foundry)

### 1. Clone the repo

```bash
git clone https://github.com/yourusername/usdd-stablecoin.git
cd usdd-stablecoin
```

### 2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 3. Install dependencies

```bash
forge install
```

### 4. Run tests

```bash
forge test
```

---

## 💻 Core Functions

| Function              | Description                                         |
| --------------------- | --------------------------------------------------- |
| `depositCollateral()` | Deposit supported collateral (wETH, wBTC, etc.)     |
| `mint()`              | Mint USDD up to safe collateral limit               |
| `burn()`              | Burn USDD to reduce debt                            |
| `redeemCollateral()`  | Withdraw collateral (if Health Factor is OK)        |
| `liquidate()`         | Liquidate undercollateralized positions (get bonus) |

---

## 🔐 Security & Design

- **Health Factor** system ensures safety (`collateral / minted`)
- **Chainlink oracles** ensure price accuracy
- **NonReentrant** and validation guards in place
- Owner-only minting/burning of USDD

---

## 📈 Business Potential

This system can be forked or expanded into:

- A **crypto-native lending protocol**
- A **multi-chain stablecoin protocol**
- A **tokenized yield vault** (USDD + DeFi integrations)
- A **modular CDP engine** for Web3 startups

Monetization ideas:
- Add stability or mint fees later
- Integrate into dApps as a native stable asset
- Tokenize liquidation rights / auctions

---

## 🧪 Sample Deployment Setup

```solidity
address[] memory tokens = [address(wETH), address(wBTC)];
address[] memory feeds = [address(wETHFeed), address(wBTCFeed)];
USDDEngine engine = new USDDEngine(tokens, feeds, address(usddToken));
```

---

## 🧩 Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Chainlink Aggregators](https://docs.chain.link/data-feeds/price-feeds/)
- [Foundry](https://book.getfoundry.sh/)

---

## 🧠 Author

🐺 [dumebai](https://github.com/dumebai)

---

## 📄 License

MIT
