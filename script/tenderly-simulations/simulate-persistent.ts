import axios from "axios";
import "dotenv/config";
import { Interface, getCreateAddress } from "ethers";
import { ADDR, BLOCK, BPF_LOADER, CREATION_BYTECODE, ENDPOINT_ID_SOLANA, GOV_ABI, RUNTIME_CODEHASH, STAR_ABI, SVM_CONTROLLER } from "./constants";

const TENDERLY_ACCESS_KEY = process.env.TENDERLY_ACCESS_KEY;
if (!TENDERLY_ACCESS_KEY) throw new Error("Missing env vars: TENDERLY_ACCESS_KEY");

function assertHex(name: string, v: string) {
  if (!/^0x[0-9a-fA-F]*$/.test(v)) throw new Error(`${name} is not valid 0x hex`);
  if (v.length < 4) throw new Error(`${name} too short`);
}

type SimTx = {
  network_id: string;
  block_number: number;
  save: boolean;
  save_if_fails: boolean;
  simulation_type: "full";
  from: string;
  to?: string; // IMPORTANT: omit for CREATE
  input: string;
  gas: number; // IMPORTANT: number (not string)
  gas_price: string;
  value: string;
  state_objects?: Record<string, any>;
};

function simBase() {
  return {
    network_id: "1",
    block_number: BLOCK,
    save: true,
    save_if_fails: false,
    simulation_type: "full" as const,
  };
}

(async () => {
  const gov = new Interface(GOV_ABI);
  const star = new Interface(STAR_ABI);

  assertHex("CREATION_BYTECODE", CREATION_BYTECODE);
  assertHex("RUNTIME_CODEHASH", RUNTIME_CODEHASH);

  const DEPLOY_NONCE = 0;
  const payloadAddr = getCreateAddress({ from: ADDR.DEPLOYER, nonce: DEPLOY_NONCE });
  console.log("Predicted payload address:", payloadAddr);

  const ETH_100 = "100000000000000000000";

  // State overrides (apply once; bundle state carries forward)
  const state_objects: Record<string, any> = {
    [ADDR.KEEL_PROXY.toLowerCase()]: { balance: ETH_100 },
    [ADDR.PAUSE_PROXY.toLowerCase()]: { balance: ETH_100 },
    [ADDR.STAR_GUARD.toLowerCase()]: { balance: ETH_100 },
    [ADDR.DEPLOYER.toLowerCase()]: { balance: ETH_100, nonce: DEPLOY_NONCE }, // nonce as number
  };

  const sims: SimTx[] = [
    // tx[0] CREATE deploy: OMIT "to"
    {
      ...simBase(),
      from: ADDR.DEPLOYER,
      input: CREATION_BYTECODE,
      gas: 8_000_000,
      gas_price: "0",
      value: "0",
      state_objects,
    },

    // tx[1] Gov: allow KEEL_PROXY -> SVM_CONTROLLER
    {
      ...simBase(),
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
    },

    // tx[2] Gov: allow KEEL_PROXY -> BPF_LOADER
    {
      ...simBase(),
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
    },

    // tx[3] StarGuard.plot(payloadAddr, RUNTIME_CODEHASH)
    {
      ...simBase(),
      from: ADDR.PAUSE_PROXY,
      to: ADDR.STAR_GUARD,
      input: star.encodeFunctionData("plot", [payloadAddr, RUNTIME_CODEHASH]),
      gas: 1_500_000,
      gas_price: "0",
      value: "0",
    },

    // tx[4] StarGuard.exec()
    {
      ...simBase(),
      from: ADDR.PAUSE_PROXY,
      to: ADDR.STAR_GUARD,
      input: star.encodeFunctionData("exec", []),
      gas: 6_000_000,
      gas_price: "0",
      value: "0",
    },
  ];

  const url = `https://api.tenderly.co/api/v1/account/matarikilabs/project/project/simulate-bundle`;

  await axios
  .post(
    url,
    { simulations: sims },
    {
      headers: {
        "X-Access-Key": TENDERLY_ACCESS_KEY,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    }
  )
  .then(() => console.log("Simulation success"))
  .catch((e) => {
    console.error("SImulation failed");
    throw e;
  });


})().catch((e) => {
  console.error(e?.response?.data ?? e);
  process.exitCode = 1;
});
