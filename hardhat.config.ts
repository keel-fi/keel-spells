import { defineConfig, configVariable } from "hardhat/config";
import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import hardhatNetworkHelpers from "@nomicfoundation/hardhat-network-helpers";

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin, hardhatNetworkHelpers],
  solidity: {
    version: "0.8.25",
  },
  networks: {
    mainnetFork: {
      type: "edr-simulated",
      forking: {
        // MAINNET_RPC_URL required for forking (archive node recommended; public RPCs may rate-limit)
        url: configVariable("MAINNET_RPC_URL") ?? "https://eth.llamarpc.com",
        blockNumber: 24192205,
      },
    },
  },
  // Use default paths; we deploy from Foundry artifacts in the test
});
