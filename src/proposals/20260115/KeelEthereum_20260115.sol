// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {
    CCTPForwarder
} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {
    LZForwarder,
    ILayerZeroEndpointV2
} from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import {
    Ethereum,
    KeelPayloadEthereum
} from "src/libraries/KeelPayloadEthereum.sol";

import {
    IRateLimits
} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";

import {
    RateLimitHelpers
} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {
    MainnetController
} from "lib/keel-alm-controller/src/MainnetController.sol";

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
    function relayRaw(
        TxParams calldata txParams,
        MessagingFee calldata fee,
        address refundAddress
    ) external payable;
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

        // [Ethereum] Keel - Execute cross-chain payload
        // Forum: TODO
        _executeAddNewRelayerCrossChainPayload();

        // [Ethereum] Keel - Execute cross-chain payload
        // Forum: TODO
        //_executeUpgradeALMControllerCrossChainPayload();
    }

    function _setCCTPMintRecipient() internal {
        // ---------- [Ethereum] Update CCTP Mint Recipient ----------
        // BEFORE : 0
        // AFTER  : TODO
        MainnetController(Ethereum.ALM_CONTROLLER).setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA,
            // TODO: move to the keel address registry
            0x3387f134e4a16b92ee3cb364cbca054a8ec384932b537620588263ec760e6b40
        );
    }

    function _executeAddNewRelayerCrossChainPayload() internal {
        // ---------- [Ethereum] Execute Add New Relayer Cross-Chain Payload ----------
        // Forum: TODO
        LZForwarder.sendMessage({
            _dstEid: ENDPOINT_ID_SOLANA,
            _receiver: Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY,
            endpoint: ILayerZeroEndpointV2(LZForwarder.ENDPOINT_ETHEREUM),
            _message: bytes("333"),
            _options: hex"00030100210100000000000000000000000000030d40000000000000000000000000001f1df0",
            _refundAddress: Ethereum.KEEL_PROXY,
            _payInLzToken: false
        });
    }

    function _executeUpgradeALMControllerCrossChainPayload() internal {
        // ---------- [Ethereum] Execute Upgrade ALM Controller Cross-Chain Payload ----------
        // Forum: TODO
        LZForwarder.sendMessage({
            _dstEid: ENDPOINT_ID_SOLANA,
            _receiver: Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY,
            endpoint: ILayerZeroEndpointV2(LZForwarder.ENDPOINT_ETHEREUM),
            _message: bytes("333"),
            _options: hex"00030100210100000000000000000000000000030d40000000000000000000000000001f1df0",
            _refundAddress: Ethereum.KEEL_PROXY,
            _payInLzToken: false
        });
    }
}
