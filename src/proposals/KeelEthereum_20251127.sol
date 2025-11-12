// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

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
    // This was calculated by decoding the Solana base58 address `EeWDutgcKNTdQGJkGRrWYmTXXuKnPUZNvXepbLkQrxW4` into hex
    bytes32 internal constant SOLANA_RECIPIENT = 0xcac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac48609;
    address internal constant USDS_OFT = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;

    function _execute() internal override {
        _changeRateLimits();
        _setRecipients();
    }

    function _changeRateLimits() internal {
        // Update USDS <> USDC RateLimit
        // before: 10k
        // After: 100M
        _setUSDSToUSDCRateLimit(100_000_000e6, 50_000_000e6 / uint256(1 days));

        // Update USDS to sUSDS RateLimit
        // before: 10k
        // After: 100M
        _onboardERC4626Vault(Ethereum.SUSDS, 100_000_000e18, 50_000_000e18 / uint256(1 days));

        // Update USDC to CCTP General RateLimit
        // before: 0
        // After: 100M
        bytes32 generalCctpKey = MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_CCTP();
        IRateLimits(Ethereum.ALM_RATE_LIMITS)
            .setRateLimitData(generalCctpKey, 100_000_000e6, 50_000_000e6 / uint256(1 days));

        // Update USDC to CCTP Solana RateLimit
        // before: 0
        // After: 100M
        bytes32 solanaCctpKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS)
            .setRateLimitData(solanaCctpKey, 100_000_000e6, 50_000_000e6 / uint256(1 days));

        // Update USDS to LayerZero Solana RateLimit
        // before: 0
        // After: 100M
        bytes32 solanaLayerZeroKey = keccak256(
            abi.encode(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_LAYERZERO_TRANSFER(),
                USDS_OFT,
                SOLANA_LAYERZERO_DESTINATION
            )
        );
        IRateLimits(Ethereum.ALM_RATE_LIMITS)
            .setRateLimitData(solanaLayerZeroKey, 100_000_000e18, 50_000_000e18 / uint256(1 days));
    }

    function _setRecipients() internal {
        // Update CCTP Mint recipient
        // before: 0
        // After: SOLANA_RECIPIENT
        MainnetController(Ethereum.ALM_CONTROLLER)
            .setMintRecipient(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, SOLANA_RECIPIENT);

        // Update LayerZero Mint recipient
        // before: 0
        // After: SOLANA_RECIPIENT
        MainnetController(Ethereum.ALM_CONTROLLER).setLayerZeroRecipient(SOLANA_LAYERZERO_DESTINATION, SOLANA_RECIPIENT);
    }
}
