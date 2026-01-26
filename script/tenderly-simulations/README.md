# Tenderly Bundle Simulation Scripts

This folder contains two TypeScript entrypoints that reproduce the Foundry test flow against an Ethereum mainnet fork at a fixed block. Both scripts execute the same sequence as a single bundle:

1. Deploy a “payload” contract via `CREATE` from a deterministic EOA.
2. Grant governance permissions (so `KEEL_PROXY` can call specific Solana targets).
3. Register the payload with `StarGuard.plot(payloadAddr, runtimeCodehash)`.
4. Execute the payload via `StarGuard.exec()`.
5. (SDK script only) Extract `LayerZero EndpointV2` `PacketSent` logs and print the encoded packets.

The goal is to match the Foundry test’s execution ordering and simulated state (including deterministic payload address and codehash checks).

---

## Common Concepts

### Deterministic payload address

Both scripts compute the payload address with:

- `payloadAddr = getCreateAddress({ from: DEPLOYER, nonce: DEPLOY_NONCE })`

This must match the deploy transaction’s actual `from` and `nonce` in the forked state. If `DEPLOY_NONCE` changes, the payload address changes, and `StarGuard.plot(...)` will register the wrong address (or revert).

### Runtime codehash requirement

`StarGuard.plot(payloadAddr, RUNTIME_CODEHASH)` validates that the deployed code at `payloadAddr` has the expected runtime codehash. Therefore:

- `CREATION_BYTECODE` must be the deploy bytecode (`forge inspect ... deployedBytecode`).
- `RUNTIME_CODEHASH` must be `keccak256(runtime/deployed bytecode)`.

If the codehash does not match, `plot` will fail.

### State overrides / balances

Both scripts inject balances (and nonce for the deployer) so the bundle can execute without funding issues:

- `DEPLOYER`, `PAUSE_PROXY`, `KEEL_PROXY`, `STAR_GUARD` get large ETH balances.
- `DEPLOYER` nonce is set explicitly to `DEPLOY_NONCE`.

Overrides are applied once, and bundle simulation carries state forward across transactions.

---

## Scripts

## `simulate-persistent.ts`

### What it does

`simulate-persistent.ts` uses Tenderly’s REST API `simulate-bundle` endpoint via `axios`. It builds an explicit `simulations: SimTx[]` payload with `save: true`, so the simulation is persisted in Tenderly (useful for sharing and debugging in the Tenderly UI).

### Transaction sequence

The bundle contains 5 simulations in order:

- `tx[0]`: `CREATE` deploy payload (important: omit `to` entirely)
- `tx[1]`: `GOV_SENDER.setCanCallTarget(KEEL_PROXY, ENDPOINT_ID_SOLANA, SVM_CONTROLLER, true)`
- `tx[2]`: `GOV_SENDER.setCanCallTarget(KEEL_PROXY, ENDPOINT_ID_SOLANA, BPF_LOADER, true)`
- `tx[3]`: `STAR_GUARD.plot(payloadAddr, RUNTIME_CODEHASH)`
- `tx[4]`: `STAR_GUARD.exec()`

### Key details

- Uses `state_objects` in the first simulation (tx[0]) to set balances and deployer nonce; the state then persists through subsequent simulations.
- For contract creation, Tenderly expects **no `to` field** (not `null`), so the script explicitly omits it.
- Uses `gas_price: "0"` and `value: "0"` for deterministic execution.


### Requirements

- `TENDERLY_ACCESS_KEY` in the environment.
- Correct `account/project` path in the URL:
  - `https://api.tenderly.co/api/v1/account/<account>/project/<project>/simulate-bundle`

---

## `simulate.ts`

### What it does

`simulate.ts` uses the official `@tenderly/sdk` to run `tenderly.simulator.simulateBundle(...)`. It prints a per-transaction OK/FAIL summary, dumps a filtered subset of trace frames when `exec` fails, and parses LayerZero `PacketSent` logs to extract the `encodedPacket` payloads.

### Transaction sequence

It runs the same 5 transactions as a single bundle:

- Deploy payload (CREATE)
- Two governance permission calls
- `StarGuard.plot(...)`
- `StarGuard.exec()`

### Key details

- For `CREATE` via the SDK, `to: null` is used, but the SDK types do not accept it cleanly, so the script casts that transaction to `any`.
- Uses `overrides` to set balances and deployer nonce.
- If `tx[4]` (exec) fails:
  - Filters the trace to frames containing `error`, `error_message`, or `revert_reason` and prints the first ~30.

### LayerZero packet extraction

After the bundle completes, the script:

- Collects logs from all simulated transactions.
- Filters logs to `ADDR.LZ_ENDPOINT` and the `PacketSent` topic.
- Decodes the event and prints `encodedPacket` for each match.

This is useful when validating that the payload’s execution emits the expected LayerZero message(s), and for comparing against Foundry-based expectations.

### Requirements

- `TENDERLY_ACCESS_KEY` in the environment.
- Tenderly client configured with the correct `accountName`, `projectName`, and `network`.

---

## How to run

1. Install dependencies (example):
   - `pnpm install`

2. Set environment:
   - `export TENDERLY_ACCESS_KEY=...`

3. Run:
   - `ts-node ./scripts/tenderly-simulations/simulate-persistent.ts`
   -  `ts-node ./scripts/tenderly-simulations/simulate.ts`


## Files

- `simulate-persistent.ts`: Raw Tenderly REST API bundle simulation, persisted (`save: true`) for UI sharing.
- `simulate.ts`: Tenderly SDK bundle simulation with exec-failure trace slicing and LayerZero `PacketSent` decoding.
