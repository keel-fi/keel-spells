import { Tenderly, Network } from "@tenderly/sdk";
import type { TransactionParameters } from "@tenderly/sdk";
import { Interface, getCreateAddress } from "ethers";
import "dotenv/config";
import { ADDR, BLOCK, BPF_LOADER, CREATION_BYTECODE, ENDPOINT_ID_SOLANA, GOV_ABI, LZ_ABI, RUNTIME_CODEHASH, STAR_ABI, SVM_CONTROLLER } from "./constants";

// -----------------------------------------------------------------------------
// Purpose
// - Reproduce the Foundry test flow in Tenderly via SDK (bundle simulation).
// - Deploy payload (CREATE), set gov permissions, StarGuard.plot(payload, codehash),
//   then StarGuard.exec() and parse LayerZero PacketSent logs.
// - If exec fails, print the first ~30 “interesting” trace frames (errors/reverts).
// -----------------------------------------------------------------------------

// Tenderly client
const tenderly = new Tenderly({
  accountName: "matarikilabs",
  projectName: "project",
  accessKey: process.env.TENDERLY_ACCESS_KEY!,
  network: Network.MAINNET,
});

function asLower(x: string) {
  return x.toLowerCase();
}

(async () => {
  const gov = new Interface(GOV_ABI);
  const star = new Interface(STAR_ABI);
  const lz = new Interface(LZ_ABI);

  // Deterministic payload address:
  // - This script deploys via CREATE from DEPLOYER with nonce=DEPLOY_NONCE.
  // - If DEPLOY_NONCE changes, payloadAddr changes, and StarGuard.plot will fail.
  // - Keep DEPLOY_NONCE aligned with overrides[DEPLOYER].nonce.
  const DEPLOY_NONCE = 0;
  const payloadAddr = getCreateAddress({ from: ADDR.DEPLOYER, nonce: DEPLOY_NONCE });
  console.log("Predicted payload address:", payloadAddr);

  // tx[0] Deploy payload (CREATE)
  // - Tenderly supports `to: null` to mean CREATE.
  // - The SDK type doesn’t accept it, so we cast this one tx only.
  const txDeploy: TransactionParameters = {
    from: ADDR.DEPLOYER,
    to: null as any,
    input: CREATION_BYTECODE,
    gas: 8_000_000,
    gas_price: "0",
    value: "0",
  } as any;

  // tx[1] Gov: allow Keel proxy to call Solana controller address (bytes32)
  const txCanCall1: TransactionParameters = {
    from: ADDR.PAUSE_PROXY,
    to: ADDR.GOV_SENDER,
    input: gov.encodeFunctionData("setCanCallTarget", [
      ADDR.KEEL_PROXY,
      ENDPOINT_ID_SOLANA,
      SVM_CONTROLLER,
      true,
    ]),
    gas: 600_000,
    gas_price: "0",
    value: "0",
  };

  // tx[2] Gov: allow Keel proxy to call Solana BPF loader address (bytes32)
  const txCanCall2: TransactionParameters = {
    from: ADDR.PAUSE_PROXY,
    to: ADDR.GOV_SENDER,
    input: gov.encodeFunctionData("setCanCallTarget", [
      ADDR.KEEL_PROXY,
      ENDPOINT_ID_SOLANA,
      BPF_LOADER,
      true,
    ]),
    gas: 600_000,
    gas_price: "0",
    value: "0",
  };

  // tx[3] StarGuard: register payload address + expected runtime codehash
  // - If codehash doesn’t match payload runtime, plot reverts (wrong-codehash).
  const txPlot: TransactionParameters = {
    from: ADDR.PAUSE_PROXY,
    to: ADDR.STAR_GUARD,
    input: star.encodeFunctionData("plot", [payloadAddr, RUNTIME_CODEHASH]),
    gas: 1_500_000,
    gas_price: "0",
    value: "0",
  };

  // tx[4] StarGuard.exec()
  const txExec: TransactionParameters = {
    from: ADDR.PAUSE_PROXY,
    to: ADDR.STAR_GUARD,
    input: star.encodeFunctionData("exec", []),
    gas: 6_000_000,
    gas_price: "0",
    value: "0",
  };

  // Overrides:
  // - nonce must be a number (Tenderly type requirement).
  // - balances are uint256 as decimal strings (Tenderly accepts decimals reliably).
  // - Give PAUSE_PROXY + STAR_GUARD enough ETH to cover msg.value + any internal forwarding.
  const ETH_100 = "100000000000000000000"; // 100 * 1e18, decimal string

  const overrides = {
    [ADDR.KEEL_PROXY.toLowerCase()]: { balance: ETH_100 },
    [ADDR.PAUSE_PROXY.toLowerCase()]: { balance: ETH_100 },
    [ADDR.STAR_GUARD.toLowerCase()]: { balance: ETH_100 },
    [ADDR.DEPLOYER.toLowerCase()]: { balance: ETH_100, nonce: DEPLOY_NONCE },
  }

  // Single bundle: deploy + perms + plot + exec
  // - Bundle runs sequentially in one simulated state, same as a Foundry test flow.
  // - If txExec fails, we dump a focused trace slice below.
  const sims = await tenderly.simulator.simulateBundle({
    blockNumber: BLOCK,
    transactions: [txDeploy, txCanCall1, txCanCall2, txPlot, txExec],
    overrides,
  });

  if (!sims) throw new Error("simulateBundle returned undefined");

  // Quick pass/fail summary
  sims.forEach((s: any, i: number) => {
    console.log(`tx[${i}]`, s.status ? "OK" : "FAIL");
    if (!s.status) {
      console.log(`tx[${i}] error:`, s.errorMessage ?? s.error_message);
      console.log(`tx[${i}] revert:`, s.revertReason ?? s.revert_reason);
    }
  });

  // If exec failed, print only the frames that carry errors/reverts
  const execSim: any = sims[4];
  if (!execSim?.status) {
    const trace: any[] = execSim.trace ?? execSim.transaction?.trace ?? [];
    const interesting = trace.filter((t) => t?.error || t?.revert_reason || t?.error_message);
    console.dir(interesting.slice(0, 30), { depth: 6 });
  }

  // -------------------- Extract LayerZero packets --------------------
  // We look for PacketSent on the EndpointV2 address and decode encodedPacket.
  const logs: any[] = sims.flatMap((s: any) => (s.transaction?.logs ?? s.logs ?? []) as any[]);
  const topic0 = lz.getEvent("PacketSent")!.topicHash.toLowerCase();

  const packets = logs.filter((l: any) => {
    const addr = asLower(l.address ?? l.raw?.address ?? "");
    const topics = l.topics ?? l.raw?.topics;
    return (
      addr === asLower(ADDR.LZ_ENDPOINT) &&
      Array.isArray(topics) &&
      asLower(topics[0] ?? "") === topic0
    );
  });

  console.log("LayerZero packets:", packets.length);

  packets.forEach((p: any, i: number) => {
    const topics = (p.topics ?? p.raw?.topics) as string[];
    const data = (p.data ?? p.raw?.data) as string;
    const decoded = lz.decodeEventLog("PacketSent", data, topics);
    console.log(`packet[${i}] encodedPacket:`, decoded.encodedPacket);
  });
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
