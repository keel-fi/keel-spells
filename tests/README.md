# ControllerManagePermission Spell – Mocha Test

This Mocha test validates the **ControllerManagePermission** cross-chain spell end-to-end.

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
pnpm hardhat test tests/spell-keel-freeze.spec.ts --network mainnetFork
```

---