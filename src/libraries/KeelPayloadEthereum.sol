// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {KeelLiquidityLayerHelpers} from "./KeelLiquidityLayerHelpers.sol";

/**
 * @dev Base smart contract for Ethereum.
 * @author Exo Tech
 */
abstract contract KeelPayloadEthereum {
    function execute() external {
        _execute();
    }

    /**
     * @notice Checks if the Keel Ethereum payload is executable in the current block
     * @dev Required, useful for implementing "earliest launch date" or "office hours" strategy
     * @return result The result of the check (true = executable, false = not)
     */
    function isExecutable() external pure returns (bool result) {
        result = true;
    }

    function _execute() internal virtual;

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        KeelLiquidityLayerHelpers.onboardERC4626Vault(Ethereum.ALM_RATE_LIMITS, vault, depositMax, depositSlope);
    }

    function _setUSDSMintRateLimit(uint256 maxAmount, uint256 slope) internal {
        KeelLiquidityLayerHelpers.setUSDSMintRateLimit(Ethereum.ALM_RATE_LIMITS, maxAmount, slope);
    }

    function _setUSDSToUSDCRateLimit(uint256 maxAmount, uint256 slope) internal {
        KeelLiquidityLayerHelpers.setUSDSToUSDCRateLimit(Ethereum.ALM_RATE_LIMITS, maxAmount, slope);
    }
}
