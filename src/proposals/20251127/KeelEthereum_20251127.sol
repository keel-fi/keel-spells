// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";

import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

/**
 * @title  November 27, 2025 Keel Ethereum Proposal
 * @notice Parameter change for rate limits
 * @author Exo Tech
 * Forum: https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406
 * Vote:  TODO
 */
contract KeelEthereum_20251127 is KeelPayloadEthereum {
    // https://docs.layerzero.network/v2/deployments/deployed-contracts?stages=mainnet&chains=solana
    uint32 internal constant SOLANA_LAYERZERO_DESTINATION = 30168;

    uint256 internal constant TRANSFER_LIMIT_E6 = 100_000_000e6;
    uint256 internal constant TRANSFER_SLOPE_E6 = 50_000_000e6 / uint256(1 days);

    uint256 internal constant TRANSFER_LIMIT_E18 = 100_000_000e18;
    uint256 internal constant TRANSFER_SLOPE_E18 = 50_000_000e18 / uint256(1 days);

    function _execute() internal override {
        // [Ethereum] Keel - Set rate limit for USDC to USDS
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20LIMIT_USDS_TO_USDC
        _changeUSDSToUSDCRateLimits();

        // [Ethereum] Keel - Set rate limit for USDS to sUSDS
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20LIMIT_4626_DEPOSIT
        _changeUSDStoSUSDSRateLimits();

        // [Ethereum] Keel - Set rate limit for USDC to CCTP General
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20LIMIT_4626_WITHDRAW
        _changeUSDCtoCCTPGeneralRateLimits();

        // [Ethereum] Keel - Set rate limit for USDC to CCTP Solana
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20LIMIT_USDC_TO_DOMAIN
        _changeUSDCtoCCTPSolanaRateLimits();

        // [Ethereum] Keel - Set rate limit for USDS to LayerZero Solana
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20LIMIT_LAYERZERO_TRANSFER
        _changeUSDStoLayerZeroSolanaRateLimits();

        // [Ethereum] Keel - Set CCTP Mint Recipient
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20mintRecipients
        _setCCTPMintRecipient();

        // [Ethereum] Keel - Set LayerZero Mint Recipient
        // Forum : https://forum.sky.money/t/november-27-2025-prime-technical-scope-parameter-change-for-upcoming-spell/27406#:~:text=%5BMainnet%5D%20layerZeroRecipients
        _setLayerZeroMintRecipient();
    }

    function _changeUSDSToUSDCRateLimits() internal {
        // ---------- [Mainnet] Update USDS to USDC Rate Limits ----------
        // BEFORE :      10,000 max ;       5,000/day slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        _setUSDSToUSDCRateLimit(TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);
    }

    function _changeUSDStoSUSDSRateLimits() internal {
        // ---------- [Mainnet] Update USDS to sUSDS Rate Limits ----------
        // BEFORE :      10,000 max ;       5,000/day slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        _onboardERC4626Vault(Ethereum.SUSDS, TRANSFER_LIMIT_E18, TRANSFER_SLOPE_E18);
    }

    function _changeUSDCtoCCTPGeneralRateLimits() internal {
        // ---------- [Mainnet] Update USDC to CCTP General Rate Limits ----------
        // BEFORE :           0 max ;           0 slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        bytes32 generalCctpKey = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(generalCctpKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);
    }

    function _changeUSDCtoCCTPSolanaRateLimits() internal {
        // ---------- [Mainnet] Update USDC to CCTP Solana Rate Limits ----------
        // BEFORE :           0 max ;           0 slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        bytes32 solanaCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS).setRateLimitData(solanaCctpKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);
    }

    function _changeUSDStoLayerZeroSolanaRateLimits() internal {
        // ---------- [Mainnet] Update USDS to LayerZero Solana Rate Limits ----------
        // BEFORE :           0 max ;           0 slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        bytes32 solanaLayerZeroKey = keccak256(
            abi.encode(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_LAYERZERO_TRANSFER(),
                Ethereum.USDS_SKY_OFT_ADAPTER,
                SOLANA_LAYERZERO_DESTINATION
            )
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS)
            .setRateLimitData(solanaLayerZeroKey, TRANSFER_LIMIT_E18, TRANSFER_SLOPE_E18);
    }

    function _setCCTPMintRecipient() internal {
        // ---------- [Mainnet] Update CCTP Mint Recipient ----------
        // BEFORE : 0
        // AFTER  : KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setMintRecipient(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY);
    }

    function _setLayerZeroMintRecipient() internal {
        // ---------- [Mainnet] Update LayerZero Mint Recipient ----------
        // BEFORE : 0
        // AFTER  : KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setLayerZeroRecipient(SOLANA_LAYERZERO_DESTINATION, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY);
    }
}
