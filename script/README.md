# Script Directory

This directory contains utility scripts for working with Keel spells, including payload extraction and validation.

## Contents

- [`extract-forge-payload.ts`](#the-extract-forge-payload-script) - Extract LayerZero packets from Forge test output
- [`extract-tenderly-payload.ts`](#extract-tenderly-payload-script) - Extract payloads from Tenderly simulations
- [`validate-spell-keel-*.ts`](#validation-scripts) - Spell validation orchestrator scripts
- [`tenderly-simulations/`](./tenderly-simulations/) - Tenderly simulation utilities

---

# Validation Scripts

Validation scripts orchestrate the end-to-end validation of governance spells that send cross-chain messages via LayerZero. They automate the process of running Forge tests, extracting LayerZero packets, and validating those packets against expected behavior on the destination chain.

## What Validation Scripts Do

1. **Run a Forge test** for a specific spell contract
2. **Extract LayerZero packets** from `PacketSent` events in the test output
3. **Validate each packet** using scripts from the `tools/payload-validations` submodule

## Prerequisites

Before running validation scripts, ensure you have:

1. **Foundry installed** - [Installation guide](https://book.getfoundry.sh/getting-started/installation)
2. **Node.js and dependencies installed**:
   ```bash
   npm install
   # or
   pnpm install
   ```
3. **Surfpool running** - Required for validation scripts to simulate Solana transactions
   ```bash
   surfpool start
   ```
4. **Payload validations submodule initialized**:
   ```bash
   git submodule update --init tools/payload-validations
   cd tools/payload-validations && yarn install
   ```

## Running a Validation Script

To run a validation script:

```bash
npx ts-node script/validate-spell-keel-20260212.ts
```

Or if the script has executable permissions:

### Expected Output

A successful run will output:

```
OK ./scripts/controller-manage-permission/validate.ts
OK ./scripts/controller-manage-permission/validate.ts
OK spell validated
```

If validation fails, the script will exit with a non-zero status code and display the error.

## Writing a Validation Script

### Naming Convention

Validation scripts follow the naming pattern:
```
validate-spell-keel-{YYYYMMDD}.ts
```

This matches the corresponding spell in `src/proposals/{YYYYMMDD}/`.

### Script Structure

Every validation script has these components:

#### 1. Shebang and Imports

```typescript
#!/usr/bin/env ts-node

import "dotenv/config";
import { spawnSync } from "node:child_process";
```

#### 2. Configuration Constants

```typescript
// Path to the validations submodule (relative to repo root)
const VALIDATIONS_REPO = "tools/payload-validations";

// Validation scripts (relative to the validations repo root)
// Each entry is [script-path, config-path]
const validations = [
  ["./scripts/controller-manage-permission/validate.ts", "./scripts/controller-manage-permission/configs/remove-relayer-1.ts"],
  ["./scripts/controller-manage-permission/validate.ts", "./scripts/controller-manage-permission/configs/remove-relayer-2.ts"],
];
```

**Important**: The number of entries in `validations` must match the number of `PacketSent` events emitted by your spell.

#### 3. The `extractPackets()` Function

This function runs the Forge test and extracts LayerZero packets:

```typescript
function extractPackets(): string[] {
  // Build the Forge command - match your test contract name
  const cmd = `
    forge test --json -vvvv --match-contract KeelEthereum_20260212Test \
    | ts-node script/extract-forge-payload.ts
  `;

  const res = spawnSync(cmd, {
    shell: true,
    stdio: ["ignore", "pipe", "inherit"],
    env: process.env,
    encoding: "utf8",
  });

  if (res.status !== 0) {
    process.exit(res.status ?? 1);
  }

  const stdout = res.stdout.trim();
  if (!stdout) {
    throw new Error("Extractor produced no output");
  }

  // Parse JSONL output from extractor
  const packets: string[] = [];
  for (const line of stdout.split("\n")) {
    const l = line.trim();
    if (!l) continue;
    try {
      const obj = JSON.parse(l);
      if (typeof obj?.packet === "string" && obj.packet.startsWith("0x")) {
        packets.push(obj.packet);
      }
    } catch {
      // Ignore non-JSON lines
    }
  }

  if (packets.length === 0) {
    throw new Error("No packet hex found in extractor output");
  }

  return packets;
}
```

#### 4. The `main()` Function

Orchestrates packet extraction and validation:

```typescript
function main() {
  const packets = extractPackets();

  // Verify packet count matches expected validations
  if (packets.length !== validations.length) {
    throw new Error("Number of packets does not match number of validations");
  }

  // Run each validation
  for (let i = 0; i < packets.length; i++) {
    const [script, config] = validations[i];
    const res = spawnSync(
      "npx",
      ["ts-node", script, "--config", config, "--packet-bytes", packets[i]],
      {
        stdio: "inherit",
        env: process.env,
        cwd: VALIDATIONS_REPO,
      }
    );

    if (res.status !== 0) {
      process.exit(res.status ?? 1);
    }

    console.log(`OK ${script}`);
  }

  console.log("OK spell validated");
}

main();
```

### Step-by-Step Guide

1. **Create a new file** in `script/` following the naming convention
2. **Update the test contract name** in `extractPackets()` to match your spell's test contract (e.g., `KeelEthereum_20260212Test`)
3. **Configure the validations array** with the appropriate validation scripts and configs from `tools/payload-validations`
4. **Run the script** to verify everything works

## How It Works

### Packet Extraction Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Validation Script                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  forge test --json -vvvv --match-contract KeelEthereum_20260212Test    │
│                                                                         │
│  Runs the spell test, which:                                           │
│  1. Deploys the spell contract                                         │
│  2. Executes the spell via StarGuard                                   │
│  3. Emits PacketSent events for each LayerZero message                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ JSON output piped to
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              extract-forge-payload.ts                                   │
│                                                                         │
│  1. Parses Forge JSON output                                           │
│  2. Finds all PacketSent(bytes,bytes,address) events                   │
│  3. Extracts encodedPayload from each event                            │
│  4. Outputs JSONL: {"i":0,"packet":"0x..."}                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Packets array
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│           tools/payload-validations/scripts/*/validate.ts               │
│                                                                         │
│  For each packet:                                                       │
│  1. Decodes the LayerZero packet                                       │
│  2. Extracts the governance instruction                                │
│  3. Simulates execution on Surfpool (local Solana)                     │
│  4. Verifies expected state changes                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

### The Extract Forge Payload Script

`extract-forge-payload.ts` is a utility that:

1. Reads Forge JSON output from stdin
2. Recursively searches for `logs` arrays in the JSON
3. Filters for `PacketSent` events (topic: `keccak256("PacketSent(bytes,bytes,address)")`)
4. Decodes the ABI-encoded event data to extract `encodedPayload`
5. Outputs JSONL to stdout

Usage:
```bash
forge test --json -vvvv --match-contract MyTest | ts-node script/extract-forge-payload.ts
```

Output format:
```json
{"i":0,"packet":"0x..."}
{"i":1,"packet":"0x..."}
```

# Extract Tenderly Payload Script

This script extracts the `dstCallData` payload from an `IGovernanceOAppSender.sendTx` call in a Tenderly simulation. The extracted payload can then be used with the crosschain payload validation scripts.

The script supports two modes:
1. **Simulate**: Create a new simulation by providing transaction parameters
2. **Fetch**: Extract payload from an existing Tenderly simulation

## Prerequisites

1. **Tenderly Account**: You need a Tenderly account with API access
2. **Environment Variables**: Set the following environment variables:
   - `TENDERLY_ACCESS_KEY`: Your Tenderly access key (found in Account Settings > Authorization)
   - `TENDERLY_ACCOUNT`: Your Tenderly account name
   - `TENDERLY_PROJECT`: Your Tenderly project name
   - `LZ_GOV_SENDER`: (Optional) Address of IGovernanceOAppSender contract (default: `0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA`)
   - `TENDERLY_NETWORK_ID`: (Optional) Network ID for simulations (default: `1` for mainnet)

## Installation

Install dependencies:

```bash
npm install
# or
pnpm install
```

## Usage

### Mode 1: Simulate New Transaction

Simulate a transaction and extract the payload directly from the simulation response:

```bash
TENDERLY_ACCESS_KEY=<key> \
TENDERLY_ACCOUNT=<account> \
TENDERLY_PROJECT=<project> \
ts-node script/extract-tenderly-payload.ts --simulate \
  --from <from-address> \
  --to <to-address> \
  --data <calldata> \
  [--value <value>] \
  [--gas <gas>] \
  [--block <block-number|latest>] \
  [--network <network-id>] \
  [output-file]
```

**Example:**
```bash
TENDERLY_ACCESS_KEY=abc123... \
TENDERLY_ACCOUNT=my-account \
TENDERLY_PROJECT=my-project \
ts-node script/extract-tenderly-payload.ts --simulate \
  --from 0x1234... \
  --to 0x5678... \
  --data 0xabcd... \
  --value 0 \
  --block latest \
  --network 1 \
  extracted-payload.txt
```

### Mode 2: Fetch Existing Simulation

Extract payload from an existing Tenderly simulation:

```bash
TENDERLY_ACCESS_KEY=<key> \
TENDERLY_ACCOUNT=<account> \
TENDERLY_PROJECT=<project> \
ts-node script/extract-tenderly-payload.ts <simulation-id> [output-file]
```

**With Tenderly URL:**
```bash
TENDERLY_ACCESS_KEY=<key> \
TENDERLY_ACCOUNT=<account> \
TENDERLY_PROJECT=<project> \
ts-node script/extract-tenderly-payload.ts "https://dashboard.tenderly.co/.../simulator/<id>" [output-file]
```

### Example

```bash
TENDERLY_ACCESS_KEY=abc123... \
TENDERLY_ACCOUNT=my-account \
TENDERLY_PROJECT=my-project \
ts-node script/extract-tenderly-payload.ts abc-def-123-456 extracted-payload.txt
```

This will:
1. Fetch the simulation from Tenderly
2. Search for the `sendTx` call to `IGovernanceOAppSender`
3. Extract the `dstCallData` from the `TxParams`
4. Write it to `extracted-payload.txt` in hex format

## Output Format

The script outputs a hex-encoded string (without `0x` prefix) that matches the format expected by the validation scripts in `crosschain-gov-solana-spell-payloads`.

Example output file:
```
000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000...
```

## Using with Validation Scripts

After extracting the payload, you can copy it to the validation scripts directory:

```bash
cp extracted-payload.txt /Users/mattauer/src/crosschain-gov-solana-spell-payloads/my-payload-mainnet.txt
```

Then run the validation:

```bash
cd /Users/mattauer/src/crosschain-gov-solana-spell-payloads
NETWORK=mainnet ts-node ./scripts/controller-manage-permission/validate.ts --file my-payload-mainnet.txt
```

## How It Works

### Simulation Mode
1. **Simulate Transaction**: Uses Tenderly API to simulate the transaction with provided parameters
2. **Use Simulation Response**: Directly uses the simulation response (no separate fetch needed)
3. **Find sendTx Call**: Recursively searches the execution trace for calls to `IGovernanceOAppSender.sendTx`
4. **Decode ABI**: Decodes the ABI-encoded function parameters to extract `TxParams`
5. **Extract Payload**: Extracts the `dstCallData` field from `TxParams`
6. **Write File**: Writes the payload as a hex string to the output file

### Fetch Mode
1. **Fetch Simulation**: Uses Tenderly API to fetch existing simulation data
2. **Find sendTx Call**: Recursively searches the execution trace for calls to `IGovernanceOAppSender.sendTx`
3. **Decode ABI**: Decodes the ABI-encoded function parameters to extract `TxParams`
4. **Extract Payload**: Extracts the `dstCallData` field from `TxParams`
5. **Write File**: Writes the payload as a hex string to the output file

## Troubleshooting

### "Could not find sendTx call"

- Verify that the simulation actually includes a call to `IGovernanceOAppSender.sendTx`
- Check that the `LZ_GOV_SENDER` address matches the contract address in your simulation
- Ensure the simulation completed successfully

### "Failed to decode sendTx input"

- The transaction input format may have changed
- Verify that the function signature matches: `sendTx((uint32,bytes32,bytes,bytes),(uint256,uint256),address)`

### API Authentication Errors

- Verify your `TENDERLY_ACCESS_KEY` is correct
- Check that your account and project names are correct
- Ensure your Tenderly account has API access enabled
