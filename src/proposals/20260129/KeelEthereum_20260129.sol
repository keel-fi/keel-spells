// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {
    Ethereum,
    KeelPayloadEthereum
} from "src/libraries/KeelPayloadEthereum.sol";

import {
    MainnetController
} from "lib/keel-alm-controller/src/MainnetController.sol";

import {IGovernanceOAppSender, TxParams, MessagingFee, MessagingReceipt} from "src/interfaces/Interfaces.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title  January 29, 2026 Keel Ethereum Proposal
 * @notice TODO
 * @author Matariki Labs
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_20260115 is KeelPayloadEthereum {
    using OptionsBuilder for bytes;
    address internal constant LZ_GOV_SENDER =
        0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;

    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;

    function _execute() internal override {
        // [Ethereum] Keel - Add a new relayer to the ALM Controller
        // Forum: TODO
        _addNewRelayer();
    }

    function _addNewRelayer() internal {
        IGovernanceOAppSender govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        TxParams memory params = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY,
            dstCallData: bytes(
                "000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c1120000840b05b00bad9fe212ef04e3246cd179f3931ffab35915bb278c8d6f6f8b672d00005bc709dc71412fe06e597212915764424ca0ee06572e2973cde4f78addbee23900018aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da36240000000000000000000000000000000000000000000000000000000000000000000000000301000001010000000000"
            ),
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(150000, 0)
        });

        MessagingFee memory fee = govSender.quoteTx(params, false);

        // ---------- [Ethereum] Add a new relayer to the ALM Controller ----------
        MessagingReceipt memory receipt = govSender.sendTx(
            params,
            fee,
            LZ_GOV_SENDER
        );
    }
}
