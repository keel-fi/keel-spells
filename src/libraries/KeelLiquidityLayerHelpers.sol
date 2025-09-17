// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {RateLimitHelpers} from "sky-star-alm-controller/src/RateLimitHelpers.sol";
import {IRateLimits} from "sky-star-alm-controller/src/interfaces/IRateLimits.sol";

/**
 * @notice Helper functions for the Keel Liquidity Layer
 */
library KeelLiquidityLayerHelpers {
    bytes32 private constant LIMIT_4626_DEPOSIT = keccak256("LIMIT_4626_DEPOSIT");
    bytes32 private constant LIMIT_4626_WITHDRAW = keccak256("LIMIT_4626_WITHDRAW");
    bytes32 private constant LIMIT_USDS_MINT = keccak256("LIMIT_USDS_MINT");
    bytes32 private constant LIMIT_USDS_TO_USDC = keccak256("LIMIT_USDS_TO_USDC");

    /**
     * @notice Onboard an ERC4626 vault
     * @dev This will set the deposit to the given numbers with
     *      the withdraw limit set to unlimited.
     */
    function onboardERC4626Vault(address rateLimits, address vault, uint256 depositMax, uint256 depositSlope)
        internal
    {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(LIMIT_4626_DEPOSIT, vault);
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(LIMIT_4626_WITHDRAW, vault);

        IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);

        IRateLimits(rateLimits).setUnlimitedRateLimitData(withdrawKey);
    }

    function setUSDSMintRateLimit(address rateLimits, uint256 maxAmount, uint256 slope) internal {
        IRateLimits(rateLimits).setRateLimitData(LIMIT_USDS_MINT, maxAmount, slope);
    }

    function setUSDSToUSDCRateLimit(address rateLimits, uint256 maxUsdcAmount, uint256 slope) internal {
        IRateLimits(rateLimits).setRateLimitData(LIMIT_USDS_TO_USDC, maxUsdcAmount, slope);
    }
}
