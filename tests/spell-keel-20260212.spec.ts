import assert from "assert";
import { spawnSync } from "node:child_process";

// validator (unchanged)
import { validateManagePermission } from "../tools/payload-validations/scripts/controller-manage-permission/validate.ts";

// canonical configs from the submodule
import cfg1 from "../tools/payload-validations/scripts/controller-manage-permission/configs/remove-relayer-1.ts";
import cfg2 from "../tools/payload-validations/scripts/controller-manage-permission/configs/remove-relayer-2.ts";

function extractPackets(): string[] {
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
      // ignore
    }
  }

  if (packets.length === 0) {
    throw new Error("No packet hex found in extractor output");
  }

  return packets;
}

describe("ControllerManagePermission spell", function () {
  this.timeout(120_000);

  it("validates packets using submodule configs", async () => {
    const packets = extractPackets();

    const configs = [cfg1, cfg2];

    assert.equal(
      packets.length,
      configs.length,
      "packet count must match config count"
    );

    for (let i = 0; i < packets.length; i++) {
      await validateManagePermission(configs[i], packets[i]);
    }
  });
});
