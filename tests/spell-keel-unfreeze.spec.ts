import assert from "assert";
import { spawnSync } from "node:child_process";

import { validateManageController } from "../tools/payload-validations/scripts/controller-manage-controller/validate.ts";

// canonical configs from the submodule
import cfg1 from "../tools/payload-validations/scripts/controller-manage-controller/configs/controller-active-mainnet.ts";

function extractPackets(): string[] {
  const cmd = `
    forge test --json -vvvv --match-contract KeelEthereum_unfreezeTest \
    | ts-node script/extract-forge-payload.ts
  `;

  const res = spawnSync(cmd, {
    shell: true,
    stdio: ["ignore", "pipe", "inherit"],
    env: process.env,
    encoding: "utf8",
  });

  if (res.status !== 0) {
    throw new Error(`forge/extractor failed (exit ${res.status})`);
  }

  const stdout = res.stdout.trim();
  if (!stdout) {
    throw new Error("Extractor produced no output");
  }

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
      // Expected: forge / extractor may emit non-JSON lines (logs, warnings).
        // These are safely ignored.
    }
  }

  if (packets.length === 0) {
    throw new Error("No packet hex found in extractor output");
  }

  return packets;
}

describe("unfreeze spell", function () {
  this.timeout(120_000);

  it("validates packets using submodule configs", async () => {
    const packets = extractPackets();

    const configs = [cfg1];

    assert.equal(
      packets.length,
      configs.length,
      "packet count must match config count"
    );

    for (let i = 0; i < packets.length; i++) {
      await validateManageController(configs[i], packets[i]);
    }
  });
});
