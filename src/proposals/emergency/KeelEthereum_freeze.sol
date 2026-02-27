// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

/**
 * @title  Emergency Keel Ethereum Proposal
 * @notice TODO
 * @author Matariki Labs
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_freeze is KeelPayloadEthereum {
    function _execute() internal override {
        // [Ethereum] Keel - Freeze the ALM Controller
        _freezeController();
    }

    function _freezeController() internal {
        _executePayload(
            hex"0005cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660001cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c11200008aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da362400000200"
        );
    }
}
