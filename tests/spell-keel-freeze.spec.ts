import assert from "node:assert";
import { describe, it } from "node:test";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { network } from "hardhat";
import {
  keccak256,
  parseEther,
  getContract,
} from "viem";
import {
  ADDRESSES,
  ENDPOINT_ID_SOLANA,
  SOLANA_SVM_CONTROLLER_PROGRAM,
  SOLANA_BPF_LOADER_V3,
} from "./hardhat-helpers/constants";

const LZ_PACKET_SENT_ABI = [
  {
    type: "event",
    name: "PacketSent",
    inputs: [
      { name: "encodedPacket", type: "bytes", indexed: false },
      { name: "options", type: "bytes", indexed: false },
      { name: "sendLibrary", type: "address", indexed: false },
    ],
  },
] as const;

function runValidateManageController(
  configPath: string,
  packetHex: string
): Promise<void> {
  return new Promise((resolve, reject) => {
    const payloadValidationsDir = join(
      process.cwd(),
      "tools",
      "payload-validations"
    );
    const child = spawn(
      "npx",
      [
        "ts-node",
        "scripts/controller-manage-controller/validate.ts",
        "--config",
        configPath,
        "--packet-bytes",
        packetHex,
      ],
      {
        cwd: payloadValidationsDir,
        stdio: ["ignore", "pipe", "pipe"],
      }
    );
    child.on("error", (error) => {
      reject(new Error(`Validation failed: ${error.message}`));
    });
    let stderr = "";
    child.stderr?.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Validation failed (exit ${code}): ${stderr}`));
    });
  });
}

const VALIDATION_CONFIGS = [
  "scripts/controller-manage-controller/configs/controller-frozen-mainnet.ts",
];

describe("freeze spell", async function () {
  const { viem, networkHelpers } = await network.connect("mainnetFork");
  const publicClient = await viem.getPublicClient();
  const [payerWallet] = await viem.getWalletClients();
  if (!payerWallet || !publicClient || !networkHelpers) {
    throw new Error("Missing wallet, public client, or network helpers");
  }

  it("validates packets using submodule configs", async () => {
    const deployedContract = await viem.deployContract("KeelEthereum_freeze", []);
    const deploymentBlockNumber = await publicClient.getBlockNumber();
    const spellAddress = deployedContract.address;

    const deployedBytecode = await publicClient.getBytecode({ address: spellAddress });
    if (!deployedBytecode) throw new Error("No bytecode at spell address");
    const bytecodeHash = keccak256(deployedBytecode);

    await networkHelpers.impersonateAccount(ADDRESSES.PAUSE_PROXY as `0x${string}`);
    await networkHelpers.setBalance(ADDRESSES.PAUSE_PROXY as `0x${string}`, parseEther("1"));
    await networkHelpers.setBalance(ADDRESSES.KEEL_PROXY as `0x${string}`, parseEther("1"));

    const pauseProxyWallet = await viem.getWalletClient(ADDRESSES.PAUSE_PROXY as `0x${string}`);
    if (!pauseProxyWallet) throw new Error("Could not get PAUSE_PROXY wallet");

    const govSender = getContract({
      address: ADDRESSES.LZ_GOV_SENDER as `0x${string}`,
      abi: [
        'function plot(address addr_, bytes32 tag_) external',
        'function exec() external returns (address addr)',
      ],
      client: { wallet: pauseProxyWallet, public: publicClient },
    });
    await govSender.write.setCanCallTarget([
      ADDRESSES.KEEL_PROXY as `0x${string}`,
      ENDPOINT_ID_SOLANA,
      SOLANA_SVM_CONTROLLER_PROGRAM as `0x${string}`,
      true,
    ]);
    await govSender.write.setCanCallTarget([
      ADDRESSES.KEEL_PROXY as `0x${string}`,
      ENDPOINT_ID_SOLANA,
      SOLANA_BPF_LOADER_V3 as `0x${string}`,
      true,
    ]);

    const starGuard = getContract({
      address: ADDRESSES.KEEL_STAR_GUARD as `0x${string}`,
      abi: [
        'function plot(address addr_, bytes32 tag_) external',
        'function exec() external returns (address addr)',
      ],
      client: { wallet: pauseProxyWallet, public: publicClient },
    });
    await starGuard.write.plot([spellAddress, bytecodeHash as `0x${string}`]);
    const execHash = await starGuard.write.exec();

    const receipt = await publicClient.waitForTransactionReceipt({ hash: execHash });
    if (receipt.status !== "success") throw new Error("Exec transaction failed");

    const packets = await publicClient.getContractEvents({
      address: ADDRESSES.LZ_ENDPOINT_V2 as `0x${string}`,
      eventName: "PacketSent",
      abi: LZ_PACKET_SENT_ABI,
      fromBlock: deploymentBlockNumber,
      strict: true,
    });

    assert.equal(
      packets.length,
      VALIDATION_CONFIGS.length,
      "packet count must match config count"
    );

    for (let i = 0; i < packets.length; i++) {
      await runValidateManageController(VALIDATION_CONFIGS[i], packets[i].args.encodedPacket);
    }
  });
});
