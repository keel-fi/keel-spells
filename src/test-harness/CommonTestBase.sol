// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5 <0.9.0;

import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

library ChainIds {
    uint256 constant MAINNET = 1;
}

contract CommonTestBase is Test {
    using stdJson for string;

    address public constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant EURE_GNOSIS = 0xcB444e90D8198415266c6a2724b7900fb12FC56E;
    address public constant USDCE_GNOSIS = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;

    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /**
     * @notice deal doesn"t support amounts stored in a script right now.
     * This function patches deal to mock and transfer funds instead.
     * @param asset the asset to deal
     * @param user the user to deal to
     * @param amount the amount to deal
     * @return bool true if the caller has changed due to prank usage
     */
    function _patchedDeal(address asset, address user, uint256 amount) internal returns (bool) {
        if (block.chainid == ChainIds.MAINNET) {
            // USDC
            if (asset == USDC_MAINNET) {
                vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
                IERC20(asset).transfer(user, amount);
                return true;
            }
        }
        return false;
    }

    /**
     * Patched version of deal
     * @param asset to deal
     * @param user to deal to
     * @param amount to deal
     */
    function deal2(address asset, address user, uint256 amount) internal {
        bool patched = _patchedDeal(asset, user, amount);
        if (!patched) {
            deal(asset, user, amount);
        }
    }

    /**
     * @dev forwards time by x blocks
     */
    function _skipBlocks(uint128 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
    }

    function _isInUint256Array(uint256[] memory haystack, uint256 needle) internal pure returns (bool) {
        for (uint256 i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) return true;
        }
        return false;
    }

    function _isInAddressArray(address[] memory haystack, address needle) internal pure returns (bool) {
        for (uint256 i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) return true;
        }
        return false;
    }
}
