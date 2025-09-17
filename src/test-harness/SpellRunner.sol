// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {console} from "forge-std/console.sol";

import {Ethereum} from "keel-address-registry/Ethereum.sol";
// import { Avalanche } from 'grove-address-registry/Avalanche.sol';
// import { Arbitrum } from 'grove-address-registry/Arbitrum.sol';
// import { Base }     from 'grove-address-registry/Base.sol';
// import { Gnosis }   from 'grove-address-registry/Gnosis.sol';
// import { Optimism } from 'grove-address-registry/Optimism.sol';
// import { Unichain } from 'grove-address-registry/Unichain.sol';

// import { IExecutor } from 'lib/grove-gov-relay/src/interfaces/IExecutor.sol';

import {Domain, DomainHelpers} from "xchain-helpers/testing/Domain.sol";
import {OptimismBridgeTesting} from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";
import {AMBBridgeTesting} from "xchain-helpers/testing/bridges/AMBBridgeTesting.sol";
import {ArbitrumBridgeTesting} from "xchain-helpers/testing/bridges/ArbitrumBridgeTesting.sol";
import {CCTPBridgeTesting} from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import {Bridge, BridgeType} from "xchain-helpers/testing/Bridge.sol";
import {RecordedLogs} from "xchain-helpers/testing/utils/RecordedLogs.sol";

import {ChainIdUtils, ChainId} from "../libraries/ChainId.sol";
import {KeelPayloadEthereum} from "../libraries/KeelPayloadEthereum.sol";

abstract contract SpellRunner is Test {
    using DomainHelpers for Domain;
    using DomainHelpers for StdChains.Chain;

    // ChainData is already taken in StdChains
    struct DomainData {
        address payload;
        // IExecutor executor;
        Domain domain;
        /// @notice on mainnet: empty
        /// on L2s: bridges that'll include txs in the L2. there can be multiple
        /// bridges for a given chain, such as canonical OP bridge and CCTP
        /// USDC-specific bridge
        Bridge[] bridges;
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
        string[] memory chains = new string[](5);
        chains[0] = "eth-mainnet";
        // chains[1] = "base-mainnet";
        // chains[2] = "arb-mainnet";
        // chains[3] = "opt-mainnet";
        // chains[4] = "avax-mainnet";

        uint256[] memory blocks = getBlocksFromDate(date, chains);

        console.log("   Mainnet block:", blocks[0]);
        // console.log("      Base block:", blocks[1]);
        // console.log("  Arbitrum block:", blocks[2]);
        // console.log("  Optimism block:", blocks[3]);
        // console.log(" Avalanche block:", blocks[4]);

        // DEFINE CUSTOM CHAINS HERE
        // setChain("unichain", ChainData({
        //     name: "Unichain",
        //     rpcUrl: vm.envString("UNICHAIN_RPC_URL"),
        //     chainId: 130
        // }));

        // CREATE FORKS WITH DYNAMICALLY DERIVED BLOCKS HERE
        chainData[ChainIdUtils.Ethereum()].domain = getChain("mainnet").createFork(blocks[0]);
        // chainData[ChainIdUtils.Base()].domain        = getChain("base").createFork(blocks[1]);
        // chainData[ChainIdUtils.ArbitrumOne()].domain = getChain("arbitrum_one").createFork(blocks[2]);
        // chainData[ChainIdUtils.Optimism()].domain    = getChain("optimism").createFork(blocks[3]);
        // chainData[ChainIdUtils.Avalanche()].domain = getChain("avalanche").createFork(blocks[4]);

        // CREATE FORKS WITH STATICALLY CHOSEN BLOCKS HERE
        // chainData[ChainIdUtils.Gnosis()].domain      = getChain("gnosis_chain").createFork(39404891);  // Gnosis block lookup is not supported by Alchemy
        // chainData[ChainIdUtils.Unichain()].domain    = getChain("unichain").createFork(17517398);
    }

    /// @dev to be called in setUp
    function setupDomains(string memory date) internal {
        setupBlocksFromDate(date);

        // We default to Ethereum domain
        chainData[ChainIdUtils.Ethereum()].domain.selectFork();

        // chainData[ChainIdUtils.Ethereum()].executor = IExecutor(Ethereum.GROVE_PROXY);
        chainData[ChainIdUtils.Ethereum()].prevController = Ethereum.ALM_CONTROLLER;
        chainData[ChainIdUtils.Ethereum()].newController = Ethereum.ALM_CONTROLLER;

        // DEFINE FOREIGN EXECUTORS HERE

        // chainData[ChainIdUtils.Base()].executor        = IExecutor(Base.GROVE_EXECUTOR);
        // chainData[ChainIdUtils.Gnosis()].executor      = IExecutor(Gnosis.GROVE_EXECUTOR);
        // chainData[ChainIdUtils.ArbitrumOne()].executor = IExecutor(Arbitrum.GROVE_EXECUTOR);
        // chainData[ChainIdUtils.Optimism()].executor    = IExecutor(Optimism.GROVE_EXECUTOR);
        // chainData[ChainIdUtils.Unichain()].executor    = IExecutor(Unichain.GROVE_EXECUTOR);

        // CREATE BRIDGES HERE

        // Arbitrum One
        // chainData[ChainIdUtils.ArbitrumOne()].bridges.push(
        //     ArbitrumBridgeTesting.createNativeBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.ArbitrumOne()].domain
        //     )
        // );
        // chainData[ChainIdUtils.ArbitrumOne()].bridges.push(
        //     CCTPBridgeTesting.createCircleBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.ArbitrumOne()].domain
        //     )
        // );

        // Base
        // chainData[ChainIdUtils.Base()].bridges.push(
        //     OptimismBridgeTesting.createNativeBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Base()].domain
        //     )
        // );
        // chainData[ChainIdUtils.Base()].bridges.push(
        //     CCTPBridgeTesting.createCircleBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Base()].domain
        //     )
        // );

        // Gnosis
        // chainData[ChainIdUtils.Gnosis()].bridges.push(
        //     AMBBridgeTesting.createGnosisBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Gnosis()].domain
        //     )
        // );

        // Optimism
        // chainData[ChainIdUtils.Optimism()].bridges.push(
        //     OptimismBridgeTesting.createNativeBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Optimism()].domain
        //     )
        // );
        // chainData[ChainIdUtils.Optimism()].bridges.push(
        //     CCTPBridgeTesting.createCircleBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Optimism()].domain
        //     )
        // );

        // Unichain
        // chainData[ChainIdUtils.Unichain()].bridges.push(
        //     OptimismBridgeTesting.createNativeBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Unichain()].domain
        //     )
        // );
        // chainData[ChainIdUtils.Unichain()].bridges.push(
        //     CCTPBridgeTesting.createCircleBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain,
        //         chainData[ChainIdUtils.Unichain()].domain
        //     )
        // );

        // Avalanche
        // chainData[ChainIdUtils.Avalanche()].bridges.push(
        //     CCTPBridgeTesting.createCircleBridge(
        //         chainData[ChainIdUtils.Ethereum()].domain, chainData[ChainIdUtils.Avalanche()].domain
        //     )
        // );

        // REGISTER CHAINS HERE
        allChains.push(ChainIdUtils.Ethereum());
        //allChains.push(ChainIdUtils.Avalanche());
        // allChains.push(ChainIdUtils.Base());
        // allChains.push(ChainIdUtils.Gnosis());
        // allChains.push(ChainIdUtils.ArbitrumOne());
        // allChains.push(ChainIdUtils.Optimism());
        // allChains.push(ChainIdUtils.Unichain());
    }

    function spellIdentifier(ChainId chainId) private view returns (string memory) {
        string memory slug = string(abi.encodePacked("Grove", chainId.toDomainString(), "_", id));
        string memory identifier = string(abi.encodePacked(slug, ".sol:", slug));
        return identifier;
    }

    function deployPayload(ChainId chainId) internal onChain(chainId) returns (address) {
        return deployCode(spellIdentifier(chainId));
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
        // only execute mainnet payload
        // executeMainnetPayload();
        // then use bridges to execute other chains' payloads
        _relayMessageOverBridges();
        // execute the foreign payloads (either by simulation or real execute)
        // _executeForeignPayloads();
    }

    /// @dev bridge contracts themselves are stored on mainnet
    function _relayMessageOverBridges() internal onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            for (uint256 j = 0; j < chainData[chainId].bridges.length; j++) {
                _executeBridge(chainData[chainId].bridges[j]);
            }
        }
    }

    /// @dev this does not relay messages from L2s to mainnet except in the case of USDC
    function _executeBridge(Bridge storage bridge) private {
        if (bridge.bridgeType == BridgeType.OPTIMISM) {
            OptimismBridgeTesting.relayMessagesToDestination(bridge, false);
        } else if (bridge.bridgeType == BridgeType.CCTP) {
            CCTPBridgeTesting.relayMessagesToDestination(bridge, false);
            CCTPBridgeTesting.relayMessagesToSource(bridge, false);
        } else if (bridge.bridgeType == BridgeType.AMB) {
            AMBBridgeTesting.relayMessagesToDestination(bridge, false);
        } else if (bridge.bridgeType == BridgeType.ARBITRUM) {
            ArbitrumBridgeTesting.relayMessagesToDestination(bridge, false);
        }
    }

    // function _executeForeignPayloads() private onChain(ChainIdUtils.Ethereum()) {
    //     for (uint256 i = 0; i < allChains.length; i++) {
    //         ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
    //         if (chainId == ChainIdUtils.Ethereum()) continue; // Don't execute mainnet

    //         // UNCOMMENT AFTER OTHER DOMAINS ARE SET UP
    //         address mainnetSpellPayload = _getForeignPayloadFromMainnetSpell(chainId);
    //         //IExecutor executor = chainData[chainId].executor;
    //         if (mainnetSpellPayload != address(0)) {
    //             // We assume the payload has been queued in the executor (will revert otherwise)
    //             chainData[chainId].domain.selectFork();
    //             uint256 actionsSetId = executor.actionsSetCount() - 1;
    //             uint256 prevTimestamp = block.timestamp;
    //             vm.warp(executor.getActionsSetById(actionsSetId).executionTime);
    //             executor.execute(actionsSetId);
    //             chainData[chainId].spellExecuted = true;
    //             vm.warp(prevTimestamp);
    //         } else {
    //             // We will simulate execution until the real spell is deployed in the mainnet spell
    //             address payload = chainData[chainId].payload;
    //             if (payload != address(0)) {
    //                 chainData[chainId].domain.selectFork();
    //                 vm.prank(address(executor));
    //                 executor.executeDelegateCall(payload, abi.encodeWithSignature("execute()"));
    //                 chainData[chainId].spellExecuted = true;
    //                 console.log("simulating execution payload for network: ", chainId.toDomainString());
    //             }
    //         }
    //     }
    // }

    // function _getForeignPayloadFromMainnetSpell(ChainId chainId)
    //     internal
    //     onChain(ChainIdUtils.Ethereum())
    //     returns (address)
    // {
    //     // RETURN PAYLOAD ADDRESSES FROM THE MAINNET SPELL HERE

    //     KeelPayloadEthereum spell = KeelPayloadEthereum(chainData[ChainIdUtils.Ethereum()].payload);
    //     //if (chainId == ChainIdUtils.Avalanche()) {
    //         //return spell.PAYLOAD_AVALANCHE();
    //         // } else if (chainId == ChainIdUtils.Base()) {
    //         //     return spell.PAYLOAD_BASE();
    //         // } else if (chainId == ChainIdUtils.Gnosis()) {
    //         //     return spell.PAYLOAD_GNOSIS();
    //         // } else if (chainId == ChainIdUtils.ArbitrumOne()) {
    //         //     return spell.PAYLOAD_ARBITRUM();
    //         // } else if (chainId == ChainIdUtils.Optimism()) {
    //         //     return spell.PAYLOAD_OPTIMISM();
    //         // } else if (chainId == ChainIdUtils.Unichain()) {
    //         //     return spell.PAYLOAD_UNICHAIN();
    //     } else {
    //         revert("Unsupported chainId");
    //     }
    // }

    // function executeMainnetPayload() internal onChain(ChainIdUtils.Ethereum()) {
    //     address payloadAddress = chainData[ChainIdUtils.Ethereum()].payload;
    //     // IExecutor executor = chainData[ChainIdUtils.Ethereum()].executor;
    //     require(_isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");

    //     vm.prank(Ethereum.PAUSE_PROXY);
    //     (bool success,) = address(executor).call(
    //         abi.encodeWithSignature("exec(address,bytes)", payloadAddress, abi.encodeWithSignature("execute()"))
    //     );
    //     require(success, "FAILED TO EXECUTE PAYLOAD");
    //     chainData[ChainIdUtils.Ethereum()].spellExecuted = true;
    // }

    function _clearLogs() internal {
        RecordedLogs.clearLogs();

        // Need to also reset all bridge indicies
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId chainId = ChainIdUtils.fromDomain(chainData[allChains[i]].domain);
            for (uint256 j = 0; j < chainData[chainId].bridges.length; j++) {
                chainData[chainId].bridges[j].lastSourceLogIndex = 0;
                chainData[chainId].bridges[j].lastDestinationLogIndex = 0;
            }
        }
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
