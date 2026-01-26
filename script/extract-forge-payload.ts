#!/usr/bin/env ts-node

/**
 * Extract FULL LayerZero packets (encodedPayload) from Forge `--json` output.
 *
 * What this script outputs:
 * - For every PacketSent(bytes encodedPayload, bytes options, address sender) log
 *   found anywhere in Forge JSON output, it extracts `encodedPayload` and writes to console.
 *
 * Important:
 * - `encodedPayload` IS the full LayerZero packet (header + message/payload).
 * - We do NOT decode PacketV1 and we do NOT slice anything off.
 *
 * Usage:
 *   forge test --json -vvvv --match-contract KeelEthereum_20260129Test \
 *     | ts-node script/extract-forge-payload.ts [output-dir]
 *
 * Example:
 *   forge test --match-contract KeelEthereum_20260129Test --json -vvvv \
 * | ts-node script/extract-forge-payload.ts test-output/payloads
 */


import { ethers } from "ethers";

// PacketSent event signature (LayerZero)
const PACKET_SENT_SIGNATURE = "PacketSent(bytes,bytes,address)";
const PACKET_SENT_TOPIC = ethers.id(PACKET_SENT_SIGNATURE);

/**
 * Parse Forge output (either one JSON blob or JSONL lines),
 * find PacketSent logs anywhere in the JSON, and write each UNIQUE packet.
 */
function extractPacketsFromForgeOutput(input: string): void {
  const trimmed = input.trim();
  if (!trimmed) {
    console.error("No input received. Pipe Forge output to this script.");
    console.error("Example: forge test --json -vvvv | ts-node script/extract-forge-payload.ts");
    process.exit(1);
  }

  // Foundry may emit:
  // - a single JSON object/array, OR
  // - JSONL (one JSON object per line)
  const objs: any[] = [];
  try {
    objs.push(JSON.parse(trimmed));
  } catch {
    for (const line of trimmed.split("\n")) {
      const l = line.trim();
      if (!l) continue;
      try {
        objs.push(JSON.parse(l));
      } catch {
        // ignore non-JSON lines
      }
    }
  }

  if (objs.length === 0) {
    console.error("Did not parse any JSON from stdin. Ensure you used: forge test --json");
    process.exit(1);
  }

  // Collect all log objects from anywhere inside the JSON (schema-agnostic).
  const allLogs: any[] = [];
  for (const obj of objs) {
    allLogs.push(...collectAllLogs(obj));
  }

  // Foundry often repeats the same log multiple times in different parts of the JSON.
  // Deduplicate by a stable content key (address + topics + data).
  const seenLogKeys = new Set<string>();

  // Print full packets (encodedPayload) as JSONL to stdout:
  // {"i":0,"packet":"0x..."}
  let outIndex = 0;

  for (const log of allLogs) {
    const topic0 = log?.topics?.[0];
    if (!topic0) continue;

    // Match PacketSent by topic0
    if (String(topic0).toLowerCase() !== PACKET_SENT_TOPIC.toLowerCase()) continue;

    const topics = Array.isArray(log.topics) ? log.topics.map(String) : [];
    const key = [String(log.address ?? ""), topics.join(","), String(log.data ?? "")].join("|");
    if (seenLogKeys.has(key)) continue;
    seenLogKeys.add(key);

    // Decode PacketSent(bytes encodedPayload, bytes options, address sender)
    try {
      const decoded = ethers.AbiCoder.defaultAbiCoder().decode(["bytes", "bytes", "address"], log.data);

      // decoded[0] is encodedPayload (FULL PACKET)
      const encodedPayload = decoded[0] as string;

      if (typeof encodedPayload !== "string" || !encodedPayload.startsWith("0x")) {
        console.warn("Decoded encodedPayload is not a 0x hex string, skipping");
        continue;
      }

      // Emit JSONL line for piping into your executor
      console.log(JSON.stringify({ i: outIndex++, packet: encodedPayload }));
    } catch (e) {
      console.warn("Failed to decode PacketSent event:", e);
    }
  }

  if (outIndex === 0) {
    console.warn(`No PacketSent events found. Parsed ${objs.length} JSON object(s), scanned ${allLogs.length} log(s).`);
  }
}

/**
 * Collect all `logs: [...]` arrays found anywhere inside an arbitrary JSON object.
 * This is iterative (stack-based) to avoid recursion depth issues.
 */
function collectAllLogs(root: any): any[] {
  const out: any[] = [];

  // Deduplicate visited objects by reference to avoid infinite loops
  // (in practice JSON parse produces an acyclic graph, but this is safe).
  const seen = new Set<any>();
  const stack = [root];

  while (stack.length) {
    const cur = stack.pop();
    if (cur == null) continue;
    if (typeof cur !== "object") continue;

    if (seen.has(cur)) continue;
    seen.add(cur);

    // If this node has a logs array, collect it.
    if (Array.isArray((cur as any).logs)) {
      for (const l of (cur as any).logs) out.push(l);
    }

    // Traverse children
    if (Array.isArray(cur)) {
      for (const v of cur) stack.push(v);
    } else {
      for (const k of Object.keys(cur)) stack.push((cur as any)[k]);
    }
  }

  return out;
}

/**
 * Main entrypoint.
 * - Reads all stdin.
 * - Calls the extractor.
 */
function main() {
  let input = "";
  process.stdin.setEncoding("utf8");

  process.stdin.on("data", (chunk) => {
    input += chunk;
  });

  process.stdin.on("end", () => {
    if (!input.trim()) {
      console.error("No input received. Pipe Forge JSON output to this script:");
      console.error("  forge test --json -vvvv | ts-node script/extract-forge-payload.ts");
      process.exit(1);
    }

    // Prints JSONL lines to stdout:
    // {"i":0,"packet":"0x..."}
    extractPacketsFromForgeOutput(input);
  });
}

if (require.main === module) {
  main();
}
