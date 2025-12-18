// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

/**
 * @title  January 15, 2026 Keel Ethereum Proposal
 * @notice Update CCTP Recipient
 * @author Matariki Labs
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_20260115 is KeelPayloadEthereum {

    function _execute() internal override {
        // [Ethereum] Keel - Update CCTP Recipient
        // Forum: TODO
        _setCCTPMintRecipient();
    }

    function _setCCTPMintRecipient() internal {
        // ---------- [Ethereum] Update CCTP Mint Recipient ----------
        // BEFORE : Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        // AFTER  : Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY_USDC_ATA
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setMintRecipient(
                CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY_USDC_ATA
            );
    }
}
