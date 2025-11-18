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
        _changeRateLimits();
        _setRecipients();
    }

    function _changeRateLimits() internal {
        // ---------- [Mainnet] Update USDS to USDC Rate Limits ----------
        // BEFORE :      10,000 max ;       5,000/day slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        _setUSDSToUSDCRateLimit(TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);

        // ---------- [Mainnet] Update USDS to sUSDS Rate Limits ----------
        // BEFORE :      10,000 max ;       5,000/day slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        _onboardERC4626Vault(Ethereum.SUSDS, TRANSFER_LIMIT_E18, TRANSFER_SLOPE_E18);

        // ---------- [Mainnet] Update USDC to CCTP General Rate Limits ----------
        // BEFORE :           0 max ;           0 slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        bytes32 generalCctpKey = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        IRateLimits(Ethereum.ALM_RATE_LIMITS)
            .setRateLimitData(generalCctpKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);

        // ---------- [Mainnet] Update USDC to CCTP Solana Rate Limits ----------
        // BEFORE :           0 max ;           0 slope
        // AFTER  : 100,000,000 max ;  50,000,000/day slope
        bytes32 solanaCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS)
            .setRateLimitData(solanaCctpKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);

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

    function _setRecipients() internal {
        // ---------- [Mainnet] Update CCTP Mint Recipient ----------
        // BEFORE : 0
        // AFTER  : KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setMintRecipient(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY);

        // ---------- [Mainnet] Update LayerZero Mint Recipient ----------
        // BEFORE : 0
        // AFTER  : KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setLayerZeroRecipient(SOLANA_LAYERZERO_DESTINATION, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY);
    }
}
