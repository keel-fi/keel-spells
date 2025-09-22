// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {MainnetControllerInit, ControllerInstance} from "lib/keel-alm-controller/deploy/MainnetControllerInit.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

/**
 * @title  October 30, 2025 Keel Ethereum Proposal
 * @notice Configure ALM Controller
 *         - Set CCTP bridge address with Solana destination as the controller_authority address
 *         - Set LZ bridge address with Solana destination as the controller_authority address
 * @author Exo Tech
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_20251030 is KeelPayloadEthereum {
    // TODO: update with actual address
    address internal constant SVM_CONTROLLER_AUTHORITY = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    uint32 internal constant SVM_CCTP_DESTINATION_ENDPOINT_ID = 5;
    uint32 internal constant SVM_LZ_DESTINATION_ENDPOINT_ID = 40168;

    function _execute() internal override {
        _configureController();
    }

    function _configureController() internal {
        // Update mint recipient for CCTP bridge
        // before: 0x0000000000000000000000000000000000000000
        // After: SVM_CONTROLLER_AUTHORITY
        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            SVM_CCTP_DESTINATION_ENDPOINT_ID, bytes32(bytes20(uint160(SVM_CONTROLLER_AUTHORITY)))
        );

        // Update layer zero recipient for LZ bridge
        // before: 0x0000000000000000000000000000000000000000
        // After: SVM_CONTROLLER_AUTHORITY
        MainnetController(Ethereum.ALM_CONTROLLER).setLayerZeroRecipient(
            SVM_LZ_DESTINATION_ENDPOINT_ID, bytes32(bytes20(uint160(SVM_CONTROLLER_AUTHORITY)))
        );
    }
}
