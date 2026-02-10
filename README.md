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
├── forge-std/          # Foundry standard library
├── keel-address-registry/  # Address registry
├── keel-alm-controller/    # ALM Controller contracts
└── xchain-helpers/     # Cross-chain utilities
```

## 🧪 Testing

### Running Tests

Run all tests:
```bash
forge test
```

Run tests with verbose output:
```bash
forge test -vvv
```

Run specific test file:
```bash
forge test --match-path "src/proposals/20251002/KeelEthereum_20251002.t.sol"
```

Run tests matching a pattern:
```bash
forge test --match-test "testSpellExecution"
```

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Solidity compiler version 0.8.25 (configured in `foundry.toml`)

### Configuration

The project uses Foundry with the following key settings in `foundry.toml`:
- Solidity version: 0.8.25
- EVM version: Cancun
- Optimizer: Disabled
- FFI: Enabled (for external calls)

## Deploy Spell

```
forge create src/proposals/<DATE>/<SpellContract.sol>:SpellContract --rpc-url <YOUR_RPC_URL> --etherscan-api-key <ETHERSCAN_API_KEY> --private-key <YOUR_PRIVATE_KEY> --broadcast --verify
```

## E2E Testing

See [here](./tests/README.md)

## Emergency Spell

### Constants

The `LZ_GOV_SENDER` is the contract we use the send the transaction and payload to LayerZero

```ts
LZ_GOV_SENDER 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA
```

The `SOLANA_SVM_CONTROLLER_PROGRAM` is the solana program address `ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd` encoded as bytes32.  It is used as the `dstTarget` for the call to `sendTx`.

```ts
SOLANA_SVM_CONTROLLER_PROGRAM 0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624
```
