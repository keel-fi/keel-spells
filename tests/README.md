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