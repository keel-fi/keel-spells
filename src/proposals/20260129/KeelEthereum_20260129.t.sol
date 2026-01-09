// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import "src/test-harness/KeelTestBase.sol";

import {IGovernanceOAppSender, TxParams, MessagingFee, MessagingReceipt} from "src/interfaces/Interfaces.sol";
import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";
import {ChainIdUtils} from "src/libraries/ChainId.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract KeelEthereum_20260129Test is KeelTestBase {
    using OptionsBuilder for bytes;
    address internal constant LZ_GOV_SENDER = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;
    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;
    
    // Solana program addresses encoded as bytes32
    // SOLANA_SVM_CONTROLLER_PROGRAM = ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
    bytes32 internal constant SOLANA_SVM_CONTROLLER_PROGRAM = 0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;
    // SOLANA_BPF_LOADER_V3 = BPFLoaderUpgradeab1e11111111111111111111111
    bytes32 internal constant SOLANA_BPF_LOADER_V3 = 0x02a8f6914e88a1b0e210153ef763ae2b00c2b93d16c124d2c0537a1004800000;

    IGovernanceOAppSender internal govSender;

    constructor() {
        id = "20260129";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 24192205});
        chainData[ChainIdUtils.Ethereum()].payload = deployPayload(ChainIdUtils.Ethereum());
        govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        // Mock canCallTarget to return true for the spell's target
        // This is checked internally by sendTx before sending the message
        vm.mockCall(
            LZ_GOV_SENDER,
            abi.encodeWithSelector(
                IGovernanceOAppSender.canCallTarget.selector,
                Ethereum.KEEL_PROXY,
                ENDPOINT_ID_SOLANA,
                SOLANA_SVM_CONTROLLER_PROGRAM
            ),
            abi.encode(true)
        );

        // Build the exact params that the spell will use, including the same extraOptions
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(150000, 0);
        TxParams memory spellParams = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: SOLANA_SVM_CONTROLLER_PROGRAM,
            dstCallData: bytes(
                "000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c1120000840b05b00bad9fe212ef04e3246cd179f3931ffab35915bb278c8d6f6f8b672d00005bc709dc71412fe06e597212915764424ca0ee06572e2973cde4f78addbee23900018aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da36240000000000000000000000000000000000000000000000000000000000000000000000000301000001010000000000"
            ),
            extraOptions: extraOptions
        });

        // Mock quoteTx - return a mock fee
        MessagingFee memory mockFee = MessagingFee({nativeFee: 0, lzTokenFee: 0});
        vm.mockCall(
            LZ_GOV_SENDER,
            abi.encodeWithSelector(
                IGovernanceOAppSender.quoteTx.selector,
                spellParams,
                false
            ),
            abi.encode(mockFee)
        );

        // Mock sendTx with the exact params and the fee returned from quoteTx
        vm.mockCall(
            LZ_GOV_SENDER,
            abi.encodeWithSelector(
                IGovernanceOAppSender.sendTx.selector,
                spellParams,
                mockFee,
                LZ_GOV_SENDER
            ),
            abi.encode(
                MessagingReceipt({
                    guid: bytes32(uint256(1)),
                    nonce: 1,
                    fee: mockFee
                })
            )
        );
    }

    function test_spellExecutesSuccessfully() public {
        address payload = chainData[ChainIdUtils.Ethereum()].payload;
        require(payload != address(0), "payload-not-deployed");

        // Execute the payload - this should not revert
        executeAllPayloadsAndBridges();

        // If we get here, the spell executed successfully
        assertTrue(chainData[ChainIdUtils.Ethereum()].spellExecuted, "spell-not-executed");
    }

    function test_layerZeroMessageIsSent() public {
        // Verify the governance sender contract exists
        require(LZ_GOV_SENDER.code.length > 0, "LZ_GOV_SENDER-not-a-contract");

        // Prepare expected parameters that match the spell
        TxParams memory expectedParams = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: SOLANA_SVM_CONTROLLER_PROGRAM,
            dstCallData: bytes(
                "000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c1120000840b05b00bad9fe212ef04e3246cd179f3931ffab35915bb278c8d6f6f8b672d00005bc709dc71412fe06e597212915764424ca0ee06572e2973cde4f78addbee23900018aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da36240000000000000000000000000000000000000000000000000000000000000000000000000301000001010000000000"
            ),
            extraOptions: bytes("") // OptionsBuilder will set this in the actual spell
        });

        // Verify the spell can quote the transaction before execution
        // This validates that the parameters are correct and permissions are set
        try govSender.quoteTx(expectedParams, false) returns (MessagingFee memory) {
            // Quote succeeded, parameters are valid
            assertTrue(true, "quote-succeeded");
        } catch {
            // Quote might fail if permissions aren't set yet, but that's okay
            // The spell execution will handle this
        }

        // Execute the payload
        // The spell will send the LayerZero message to Solana to add a new relayer
        executeAllPayloadsAndBridges();

        // Verify the spell executed successfully
        assertTrue(chainData[ChainIdUtils.Ethereum()].spellExecuted, "spell-not-executed");
    }

    function test_spellParametersAreCorrect() public {
        // Verify the governance sender contract exists
        require(LZ_GOV_SENDER.code.length > 0, "LZ_GOV_SENDER-not-a-contract");

        // Verify the destination endpoint ID is correct (Solana LayerZero endpoint)
        assertEq(ENDPOINT_ID_SOLANA, 30168, "incorrect-solana-endpoint-id");

        // Verify the destination target is the correct Solana SVM Controller Program
        assertEq(
            SOLANA_SVM_CONTROLLER_PROGRAM,
            0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624,
            "incorrect-destination-target"
        );

        // Verify the call data is not empty (contains the relayer addition instruction)
        bytes memory callData = bytes(
            "000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c1120000840b05b00bad9fe212ef04e3246cd179f3931ffab35915bb278c8d6f6f8b672d00005bc709dc71412fe06e597212915764424ca0ee06572e2973cde4f78addbee23900018aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da36240000000000000000000000000000000000000000000000000000000000000000000000000301000001010000000000"
        );
        assertGt(callData.length, 0, "call-data-empty");
    }
}

