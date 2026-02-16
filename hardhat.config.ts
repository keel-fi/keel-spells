import "dotenv/config";
import { defineConfig, configVariable } from "hardhat/config";
import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import hardhatNetworkHelpers from "@nomicfoundation/hardhat-network-helpers";

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin, hardhatNetworkHelpers],
  solidity: {
    version: "0.8.25",
    settings: {
      optimizer: {
        enabled: false,
      },
      evmVersion: "cancun",
    },
  },
  paths: {
    sources: "./src",
    tests: {
      solidity: "./src", // Look for .t.sol files in src/ directory
    },
    cache: "./cache",
    artifacts: "./artifacts",
  },
  // Remappings for Solidity imports (similar to Foundry)
  // Hardhat automatically resolves node_modules, but we can configure additional paths
  // The @layerzerolabs/ remapping is handled automatically via node_modules
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
  test: {
    solidity: {
      ffi: true, // Enable FFI for vm.ffi() calls in SpellRunner.sol
    },
  },
});
