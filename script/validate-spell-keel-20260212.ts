#!/usr/bin/env ts-node

/**
 * Spell orchestrator
 *
 * What this script does:
 *
 * 1. Runs a Forge test for a specific spell
 * 2. Pipes Forge JSON output into `extract-forge-payload.ts`
 * 3. Collects the extracted LayerZero packets (FULL encodedPayloads)
 * 4. Runs validation scripts that live in the payload-validations submodule
 *
 * NOTE: surfpool must be running.
 */

import "dotenv/config";
import { spawnSync } from "node:child_process";

// Path to the validations submodule (relative to repo root)
const VALIDATIONS_REPO = "tools/payload-validations";

// Validation scripts (relative to the validations repo root)
const validations = [
  ["./scripts/controller-manage-permission/validate.ts", "./scripts/controller-manage-permission/configs/remove-relayer-1.ts"],
  ["./scripts/controller-manage-permission/validate.ts", "./scripts/controller-manage-permission/configs/remove-relayer-2.ts"],
];

/**
 * Runs:
 *
 *   forge test --json -vvvv --match-contract KeelEthereum_20260212Test
 *     | ts-node script/extract-forge-payload.ts
 *
 * and captures stdout.
 *
 * The extractor prints JSONL lines of the form:
 *
 *   {"i":0,"packet":"0x..."}
 *
 * This function parses those lines and returns the packets.
 */
function extractPackets(): string[] {
  // EXACT working shell command — do not change
  const cmd = `
    forge test --json -vvvv --match-contract KeelEthereum_20260212Test \
    | ts-node script/extract-forge-payload.ts
  `;

  // Run synchronously so nothing exits early
  const res = spawnSync(cmd, {
    shell: true,
    stdio: ["ignore", "pipe", "inherit"], // capture stdout, show stderr
    env: process.env,
    encoding: "utf8",
  });

  // If forge or extractor failed, stop immediately
  if (res.status !== 0) {
    process.exit(res.status ?? 1);
  }

  const stdout = res.stdout.trim();
  if (!stdout) {
    throw new Error("Extractor produced no output");
  }

  const packets: string[] = [];

  // The extractor prints JSONL, not raw hex
  for (const line of stdout.split("\n")) {
    const l = line.trim();
    if (!l) continue;

    try {
      const obj = JSON.parse(l);

      // Expect { i: number, packet: "0x..." }
      if (typeof obj?.packet === "string" && obj.packet.startsWith("0x")) {
        packets.push(obj.packet);
      }
    } catch {
      // Ignore non-JSON lines (defensive)
    }
  }

  if (packets.length === 0) {
    throw new Error("No packet hex found in extractor output");
  }

  return packets;
}

/**
 * Main orchestration logic
 */
function main() {
  // Extract packets from Forge run
  const packets = extractPackets();

  if (packets.length !== validations.length) {
    throw new Error("Number of packets does not match number of validations");
  }

  // Run each validation script exactly the same way
  // as they are currently run inside the validations repo
  for (let i = 0; i < packets.length; i++) {
    const [script, config] = validations[i];
    const res = spawnSync(
      "npx",
      ["ts-node", script, "--config", config, "--packet-bytes", packets[i]],
      {
        stdio: "inherit",          // show validation output
        env: process.env,          // pass env vars through
        cwd: VALIDATIONS_REPO,     // IMPORTANT: run inside submodule
      }
    );

    if (res.status !== 0) {
      process.exit(res.status ?? 1);
    }

    console.log(`OK ${script}`);
  }

  console.log("OK spell validated");
}

// Entry point
main();
