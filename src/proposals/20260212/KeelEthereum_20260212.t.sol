// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import "src/test-harness/KeelTestBase.sol";

import {IGovernanceOAppSender, TxParams, MessagingFee, MessagingReceipt} from "src/interfaces/Interfaces.sol";
import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";
import {ChainIdUtils} from "src/libraries/ChainId.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {console} from "forge-std/console.sol";

contract KeelEthereum_20260212Test is KeelTestBase {
    using OptionsBuilder for bytes;
    address internal constant LZ_GOV_SENDER = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;
    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;

    // Solana program addresses encoded as bytes32
    // SOLANA_SVM_CONTROLLER_PROGRAM = ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
    bytes32 internal constant SOLANA_SVM_CONTROLLER_PROGRAM =
        0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;
    // SOLANA_BPF_LOADER_V3 = BPFLoaderUpgradeab1e11111111111111111111111
    bytes32 internal constant SOLANA_BPF_LOADER_V3 = 0x02a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a1004800000;

    IGovernanceOAppSender internal govSender;

    constructor() {
        id = "20260212";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 24192205});
        chainData[ChainIdUtils.Ethereum()].payload = deployPayload(ChainIdUtils.Ethereum());
        govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        // Verify canCallTarget returns true for the spell's target
        // This is checked internally by sendTx before sending the message
        vm.prank(Ethereum.PAUSE_PROXY);
        govSender.setCanCallTarget(Ethereum.KEEL_PROXY, ENDPOINT_ID_SOLANA, SOLANA_SVM_CONTROLLER_PROGRAM, true);

        vm.prank(Ethereum.PAUSE_PROXY);
        govSender.setCanCallTarget(Ethereum.KEEL_PROXY, ENDPOINT_ID_SOLANA, SOLANA_BPF_LOADER_V3, true);

        // Fund the proxy that will execute the spell with ETH to pay for LayerZero messaging fees
        // The spell executes via delegatecall, so address(this).balance in the spell refers to the proxy's balance
        vm.deal(Ethereum.KEEL_PROXY, 1 ether);
    }

    function test_spellExecutesSuccessfully() public {
        address payload = chainData[ChainIdUtils.Ethereum()].payload;
        require(payload != address(0), "payload-not-deployed");

        // Execute the payload - this should not revert
        executeAllPayloadsAndBridges();

        // If we get here, the spell executed successfully
        assertTrue(chainData[ChainIdUtils.Ethereum()].spellExecuted, "spell-not-executed");
    }

    function test_spellExecutesAndCapturesPayloads() public {
        address payload = chainData[ChainIdUtils.Ethereum()].payload;
        require(payload != address(0), "payload-not-deployed");

        // Start capturing LayerZero payloads before execution
        startCaptureLayerZeroPayloads();

        // Execute the payload - this should not revert
        executeAllPayloadsAndBridges();

        // Capture and save payloads to files
        (string[] memory filePaths, bytes[] memory payloads) = captureLayerZeroPayloads();

        // Verify payloads were captured
        assertTrue(payloads.length > 0, "no-payloads-captured");
        assertTrue(bytes(filePaths[0]).length > 0, "no-file-paths-returned");

        // Verify spell executed successfully
        assertTrue(chainData[ChainIdUtils.Ethereum()].spellExecuted, "spell-not-executed");

        // Log captured payload information
        console.log("Captured payloads:", payloads.length);
        for (uint256 i = 0; i < payloads.length; i++) {
            console.log("Payload index:", i);
            console.log("Payload size:", payloads[i].length);
            console.log("Saved to:", filePaths[i]);
        }
    }
}
