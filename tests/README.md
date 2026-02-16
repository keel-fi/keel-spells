# Spell Testing

## Prerequisites

- [Node.js](https://nodejs.org/) (v20 or later)
- [pnpm](https://pnpm.io/) package manager
- `surfpool` installed and running:
 ```bash
 surfpool start
 ```
- Submodules initialized:
 ```bash
 git submodule update --init --recursive
 ```

---

## How to run

Run all tests (Solidity + TypeScript):
```bash
pnpm test
```

Run only TypeScript e2e tests:
```bash
pnpm test:ts
```

Run only Solidity tests:
```bash
pnpm test:solidity
```

---