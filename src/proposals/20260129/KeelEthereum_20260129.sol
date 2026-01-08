// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

import {IGovernanceOAppSender} from "src/interfaces/Interfaces.sol";

/**
 * @title  January 29, 2026 Keel Ethereum Proposal
 * @notice TODO
 * @author Matariki Labs
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_20260115 is KeelPayloadEthereum {
    address internal constant LZ_GOV_SENDER = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;

    
    function _execute() internal override {
        // [Ethereum] Keel - Add a new relayer to the ALM Controller
        // Forum: TODO
        _addNewRelayer();
    }

    function _addNewRelayer() internal {
        // ---------- [Ethereum] Add a new relayer to the ALM Controller ----------
        // BEFORE : TODO
        // AFTER  : TODO
        IGovernanceOAppSender(LZ_GOV_SENDER).sendTx(_params, _fee, _refundAddress);
    }
}
