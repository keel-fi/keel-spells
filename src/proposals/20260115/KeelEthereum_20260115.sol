// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {LZForwarder, ILayerZeroEndpointV2} from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";

import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

interface L1GovernanceRelayLike {
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct TxParams {
        uint32 dstEid;
        bytes32 dstTarget;
        bytes dstCallData;
        bytes extraOptions;
    }

    function l1Oapp() external view returns (address);
    function relayEVM(
        uint32 dstEid,
        address l2GovernanceRelay,
        address target,
        bytes calldata targetData,
        bytes calldata extraOptions,
        MessagingFee calldata fee,
        address refundAddress
    ) external payable;
    function relayRaw(TxParams calldata txParams, MessagingFee calldata fee, address refundAddress) external payable;
}

/**
 * @title  January 15, 2026 Keel Ethereum Proposal
 * @notice Update CCTP Recipient and execute cross-chain payload
 * @author Exo Tech
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_20260115 is KeelPayloadEthereum {
    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;

    function _execute() internal override {
        // [Ethereum] Keel - Update CCTP Recipient
        // Forum: TODO
        _setCCTPMintRecipient();
    }

    function _setCCTPMintRecipient() internal {
        // ---------- [Ethereum] Update CCTP Mint Recipient ----------
        // BEFORE : 0
        // AFTER  : TODO
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setMintRecipient(
                CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY_USDC_ATA
            );
    }
}
