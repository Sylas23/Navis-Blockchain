<!-- ///////////////// INFO FOR AUDIT /////////////////////////// -->

# NavisWar

NavisWar is a **GameFi Play and Earn** board battleship strategy game where users engage in thrilling naval battles using **Navis NFT ships**.

## Table of Contents

- [Game Modes](#game-modes)
  - [Free-to-Play Mode](#free-to-play-mode)
  - [Play-and-Earn Mode](#play-and-earn-mode)
- [NFTs](#nfts)
- [Tokenomics](#tokenomics)
- [Contracts in Scope for Audit](#contracts-in-scope-for-audit)
- [Getting Started](#getting-started)
- [Roadmap](#roadmap)
- [Community](#community)
- [License](#license)

## Game Modes

### Free-to-Play Mode

The **Free-to-Play (FTP) mode** is accessible to everyone upon the initial launch of the NavisWar game. This mode allows new users to dive into the game without any initial investment.

- **Minting Base NFTs:**  
  When new users join, six (6) **base NFTs** will be minted for them.  
  - These NFTs are **soulbound** and **valueless**.
  - Users **cannot buy, sell, or burn** the six base NFTs.
  - The free NFTs are implemented as **ERC1155** tokens, ensuring they remain consistent and identical for all players.

### Play-and-Earn Mode

The **Play-and-Earn mode** offers an enhanced gaming experience where users can earn rewards through strategic gameplay.

- **Premium NFTs:**  
  To qualify for earning rewards, users must purchase **premium NFTs**.  
  - These NFTs come with **special abilities** that set them apart from the free ships.
  - **Flexibility:**  
    The special abilities of these NFTs are managed by the app backend rather than being hard-coded into the smart contracts, allowing for dynamic updates and flexibility.

- **Token Transactions:**  
  - Users **purchase premium NFTs** using the **Navix token**.
  - Engaging in battles with premium NFTs earns users the **in-game token Marin**.
  - **Marin Token:**  
    - Marin can be **exchanged** for **Navix**, creating a robust in-game economy.

## NFTs

NavisWar utilizes two types of NFTs to enhance the gaming experience:

1. **Base NFTs (ERC1155):**  
   - **Quantity:** 6 per user.
   - **Characteristics:**  
     - Soulbound  
     - Valueless  
     - Non-transferable  
     - Identical for all players

2. **Premium NFTs (ERC721):**  
   - **Purchase:** Requires Navix tokens.
   - **Characteristics:**  
     - Unique abilities  
     - Transferable  
     - Tradable on the marketplace

## Tokenomics

- **Navix Token:**  
  - **Purpose:** Used to purchase premium NFTs and participate in the in-game economy.
  
- **Marin Token:**  
  - **Earning:** Earned by battling with premium NFTs.
  - **Utility:** Can be exchanged for Navix tokens, incentivizing active participation and gameplay.

## Contracts in Scope for Audit

The following smart contracts are slated for auditing to ensure security, efficiency, and compliance:

- [`Marin.sol`](./contracts/Marin.sol)
- [`NavixMarketplace.sol`](./contracts/NavixMarketplace.sol)
- [`NavisNFT.sol`](./contracts/NavisNFT.sol)
- [`NavixToken.sol`](./contracts/NavixToken.sol)


///////////////////////////////////////////////////////////////////////////////////

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
