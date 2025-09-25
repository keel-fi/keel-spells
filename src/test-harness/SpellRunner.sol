// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {console} from "forge-std/console.sol";

import {Ethereum} from "keel-address-registry/Ethereum.sol";

import {Domain, DomainHelpers} from "xchain-helpers/testing/Domain.sol";
import {OptimismBridgeTesting} from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";
import {AMBBridgeTesting} from "xchain-helpers/testing/bridges/AMBBridgeTesting.sol";
import {ArbitrumBridgeTesting} from "xchain-helpers/testing/bridges/ArbitrumBridgeTesting.sol";
import {CCTPBridgeTesting} from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import {RecordedLogs} from "xchain-helpers/testing/utils/RecordedLogs.sol";

import {ChainIdUtils, ChainId} from "../libraries/ChainId.sol";
import {KeelPayloadEthereum} from "../libraries/KeelPayloadEthereum.sol";

abstract contract SpellRunner is Test {
    using DomainHelpers for Domain;
    using DomainHelpers for StdChains.Chain;

    // ChainData is already taken in StdChains
    struct DomainData {
        address payload;
        address executor;
        Domain domain;
        address prevController;
        address newController;
        bool spellExecuted;
    }

    mapping(ChainId => DomainData) internal chainData;

    ChainId[] internal allChains;
    string internal id;

    modifier onChain(ChainId chainId) {
        uint256 currentFork = vm.activeFork();
        selectChain(chainId);
        _;
        if (vm.activeFork() != currentFork) vm.selectFork(currentFork);
    }

    function selectChain(ChainId chainId) internal {
        if (chainData[chainId].domain.forkId != vm.activeFork()) chainData[chainId].domain.selectFork();
    }

    /// @dev maximum 3 chains in 1 query
    function getBlocksFromDate(string memory date, string[] memory chains) internal returns (uint256[] memory blocks) {
        blocks = new uint256[](chains.length);

        // Process chains in batches of 3
        for (uint256 batchStart; batchStart < chains.length; batchStart += 3) {
            uint256 batchSize = chains.length - batchStart < 3 ? chains.length - batchStart : 3;
            string[] memory batchChains = new string[](batchSize);

            // Create batch of chains
            for (uint256 i = 0; i < batchSize; i++) {
                batchChains[i] = chains[batchStart + i];
            }

            // Build networks parameter for this batch
            string memory networks = "";
            for (uint256 i = 0; i < batchSize; i++) {
                if (i == 0) {
                    networks = string(abi.encodePacked("networks=", batchChains[i]));
                } else {
                    networks = string(abi.encodePacked(networks, "&networks=", batchChains[i]));
                }
            }

            string[] memory inputs = new string[](8);
            inputs[0] = "curl";
            inputs[1] = "-s";
            inputs[2] = "--request";
            inputs[3] = "GET";
            inputs[4] = "--url";
            inputs[5] = string(
                abi.encodePacked(
                    "https://api.g.alchemy.com/data/v1/",
                    vm.envString("ALCHEMY_API_KEY"),
                    "/utility/blocks/by-timestamp?",
                    networks,
                    "&timestamp=",
                    date,
                    "&direction=AFTER"
                )
            );
            inputs[6] = "--header";
            inputs[7] = "accept: application/json";

            string memory response = string(vm.ffi(inputs));

            // Store results in the correct positions of the final blocks array
            for (uint256 i = 0; i < batchSize; i++) {
                blocks[batchStart + i] =
                    vm.parseJsonUint(response, string(abi.encodePacked(".data[", vm.toString(i), "].block.number")));
            }
        }
    }

    function setupBlocksFromDate(string memory date) internal {
        // ADD MORE CHAINS HERE
        string[] memory chains = new string[](1);
        chains[0] = "eth-mainnet";

        uint256[] memory blocks = getBlocksFromDate(date, chains);

        console.log("   Mainnet block:", blocks[0]);

        // CREATE FORKS WITH DYNAMICALLY DERIVED BLOCKS HERE
        chainData[ChainIdUtils.Ethereum()].domain = getChain("mainnet").createFork(blocks[0]);
    }

    function setupDomain(uint256 mainnetForkBlock) internal {
        string memory mainnetRpcUrl;
        try vm.envString("MAINNET_RPC_URL") returns (string memory envRpcUrl) {
            mainnetRpcUrl = envRpcUrl;
        } catch {
            mainnetRpcUrl = getChain("mainnet").rpcUrl;
        }
        vm.createSelectFork(mainnetRpcUrl, mainnetForkBlock);
        chainData[ChainIdUtils.Ethereum()].executor = Ethereum.KEEL_PROXY;
    }

    /// @dev to be called in setUp
    function setupDomains(string memory date) internal {
        setupBlocksFromDate(date);

        // We default to Ethereum domain
        chainData[ChainIdUtils.Ethereum()].domain.selectFork();

        // chainData[ChainIdUtils.Ethereum()].executor = IExecutor(Ethereum.KEEL_PROXY);
        chainData[ChainIdUtils.Ethereum()].executor = Ethereum.KEEL_PROXY;
        chainData[ChainIdUtils.Ethereum()].prevController = Ethereum.ALM_CONTROLLER;
        chainData[ChainIdUtils.Ethereum()].newController = Ethereum.ALM_CONTROLLER;

        // DEFINE FOREIGN EXECUTORS HERE

        // CREATE BRIDGES HERE

        // REGISTER CHAINS HERE
        allChains.push(ChainIdUtils.Ethereum());
    }

    function spellIdentifier(ChainId chainId) private view returns (string memory) {
        string memory slug = string(abi.encodePacked("Keel", chainId.toDomainString(), "_", id));
        string memory identifier = string(abi.encodePacked(slug, ".sol:", slug));
        return identifier;
    }

    function deployPayload(ChainId chainId) internal onChain(chainId) returns (address) {
        address payload = deployCode(spellIdentifier(chainId));
        chainData[chainId].payload = payload;
        return payload;
    }

    function deployPayloads() internal {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            string memory identifier = spellIdentifier(chainId);
            try vm.getCode(identifier) {
                chainData[chainId].payload = deployPayload(chainId);
                chainData[chainId].spellExecuted = false;
                console.log("deployed payload for network: ", chainId.toDomainString());
                console.log("             payload address: ", chainData[chainId].payload);
            } catch {
                console.log("skipping spell deployment for network: ", chainId.toDomainString());
            }
        }
    }

    /// @dev takes care to revert the selected fork to what was chosen before
    function executeAllPayloadsAndBridges() internal {
        address payloadAddress = chainData[ChainIdUtils.Ethereum()].payload;
        address executor = chainData[ChainIdUtils.Ethereum()].executor;

        require(_isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");

        vm.prank(Ethereum.PAUSE_PROXY);
        (bool success,) = executor.call(
            abi.encodeWithSignature("exec(address,bytes)", payloadAddress, abi.encodeWithSignature("execute()"))
        );
        require(success, "FAILED TO EXECUTE PAYLOAD");
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
