# ControllerManagePermission Spell – Mocha Test

This Mocha test validates the **ControllerManagePermission** cross-chain spell end-to-end.

It replaces the previous TS CLI orchestration with a CI-friendly test that:
- runs the Forge test,
- extracts LayerZero packet bytes,
- and validates each packet using the **exported validation logic** from the `payload-validations` submodule.

---

## What this test does

1. Runs:
   ```bash
   forge test --json -vvvv --match-contract KeelEthereum_20260212Test
   ```
2. Pipes the output into `extract-forge-payload.ts` to collect packet bytes.
3. Loads **canonical configs** from the `payload-validations` submodule.
4. Calls `validateManagePermission(config, packetBytes)` for each packet.
5. Fails if extraction or validation fails.

---

## Prerequisites

- Forge installed and available in `$PATH`
- `surfpool` running
- Node.js + pnpm
- Submodules initialized:
  ```bash
  git submodule update --init --recursive
  ```

---

## How to run

```bash
pnpm mocha -r ts-node/register/transpile-only tests/spell-keel-20260212.spec.ts
```

Or via `package.json`:

```json
{
  "scripts": {
    "test:spell": "mocha -r ts-node/register/transpile-only tests/spell-keel-20260212.spec.ts"
  }
}
```

```bash
pnpm run test:spell
```

---

## Notes

- Validation logic is imported directly from the submodule (no duplication).
- Packet bytes are passed directly (no file-based payloads).
- Uses CommonJS resolution via `transpile-only` to avoid ESM import issues.
- Designed to run unchanged in CI.