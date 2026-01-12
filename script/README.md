# Extract Tenderly Payload Script

This script extracts the `dstCallData` payload from an `IGovernanceOAppSender.sendTx` call in a Tenderly simulation. The extracted payload can then be used with the crosschain payload validation scripts located at `/Users/mattauer/src/crosschain-gov-solana-spell-payloads`.

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
