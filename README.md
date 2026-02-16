# Keel Spells
Governance Spells for Keel

## ✨ Spells
The latest spells can be found in the `src/proposals/` directory. Spells are organized by date in YYYYMMDD format, with separate files for each network (e.g., `KeelEthereum_20251002.sol`).

## 📁 Project Structure

```
src/
├── libraries/           # Shared utility libraries
│   ├── ChainId.sol
│   ├── KeelLiquidityLayerHelpers.sol
│   └── KeelPayloadEthereum.sol
├── proposals/           # Governance spell implementations
│   └── 20251002/       # Organized by date (YYYYMMDD)
│       ├── KeelEthereum_20251002.sol      # Spell implementation
│       └── KeelEthereum_20251002.t.sol    # Spell tests
└── test-harness/       # Testing utilities and base classes
    ├── CommonSpellAssertions.sol
    ├── CommonTestBase.sol
    ├── KeelLiquidityLayerTests.sol
    ├── KeelTestBase.sol
    └── SpellRunner.sol

lib/                    # External dependencies
├── dss-allocator/      # DSS Allocator contracts
├── forge-std/          # Foundry standard library (for Solidity tests)
├── keel-address-registry/  # Address registry
├── keel-alm-controller/    # ALM Controller contracts
└── xchain-helpers/     # Cross-chain utilities
```

## 🧪 Testing

### Running Tests

Run all tests (Solidity + TypeScript):
```bash
pnpm test
# or
hardhat test
```

Run only Solidity tests:
```bash
pnpm test:solidity
# or
hardhat test solidity
```

Run only TypeScript tests:
```bash
pnpm test:ts
# or
hardhat test tests/*.ts --network mainnetFork
```

Run specific Solidity test file:
```bash
hardhat test src/proposals/emergency/KeelEthereum_freeze.t.sol
```

Run tests with verbose output:
```bash
hardhat test --verbose
```

### Prerequisites

- [Node.js](https://nodejs.org/) (v20 or later)
- [pnpm](https://pnpm.io/) package manager
- Solidity compiler version 0.8.25 (configured in `hardhat.config.ts`)

### Configuration

The project uses Hardhat with the following key settings in `hardhat.config.ts`:
- Solidity version: 0.8.25
- EVM version: Cancun
- Optimizer: Disabled
- FFI: Enabled (for external calls in Solidity tests)
- Test paths: Solidity tests in `src/` directory (`.t.sol` files)

Hardhat 3 supports Solidity tests with `forge-std` and all Foundry cheatcodes (`vm.*` functions), so existing Solidity test files work without modification.

## Deploy Spell

Deploy using Hardhat scripts or Hardhat Ignition. Example:

```bash
hardhat run scripts/deploy-spell.ts --network mainnet
```

Or use Hardhat Ignition for more complex deployments.

## E2E Testing

See [here](./tests/README.md)

## Emergency Spell

### Constants

The `LZ_GOV_SENDER` is the contract we use to send the transaction and payload to LayerZero

```ts
LZ_GOV_SENDER 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA
```

The `SOLANA_SVM_CONTROLLER_PROGRAM` is the Solana program address `ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd` encoded as bytes32.  It is used as the `dstTarget` for the call to `sendTx`.

```ts
SOLANA_SVM_CONTROLLER_PROGRAM 0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624
```
