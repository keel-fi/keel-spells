// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import {Ethereum} from "keel-address-registry/Ethereum.sol";

import {IALMProxy} from "keel-alm-controller/src/interfaces/IALMProxy.sol";
import {IRateLimits} from "keel-alm-controller/src/interfaces/IRateLimits.sol";
import {MainnetController} from "keel-alm-controller/src/MainnetController.sol";
import {RateLimitHelpers} from "keel-alm-controller/src/RateLimitHelpers.sol";

import {KeelLiquidityLayerHelpers} from "src/libraries/KeelLiquidityLayerHelpers.sol";

import {ChainId, ChainIdUtils} from "../libraries/ChainId.sol";

import {SpellRunner} from "./SpellRunner.sol";

import {console} from "forge-std/console.sol";

struct KeelLiquidityLayerContext {
    address controller;
    IALMProxy proxy;
    IRateLimits rateLimits;
    address relayer;
    address freezer;
}

struct CentrifugeConfig {
    address centrifugeRoot;
    address centrifugeInvestmentManager;
    bytes16 centrifugeTrancheId;
    uint64 centrifugePoolId;
    uint128 centrifugeAssetId;
}

interface IInvestmentManager {
    function fulfillCancelDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 fulfillment
    ) external;
    function fulfillCancelRedeemRequest(uint64 poolId, bytes16 trancheId, address user, uint128 assetId, uint128 shares)
        external;
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function poolManager() external view returns (address);
}

interface IPoolManager {
    function assetToId(address asset) external view returns (uint128);
}

interface IFreelyTransferableHookLike {
    function updateMember(address token, address user, uint64 validUntil) external;
}

interface IAsyncRedeemManagerLike {
    function issuedShares(uint64 poolId, bytes16 scId, uint128 shareAmount, uint128 pricePoolPerShare) external;
    function revokedShares(
        uint64 poolId,
        bytes16 scId,
        uint128 assetId,
        uint128 assetAmount,
        uint128 shareAmount,
        uint128 pricePoolPerShare
    ) external;
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 scId,
        address user,
        uint128 assetId,
        uint128 fulfilledAssets,
        uint128 fulfilledShares,
        uint128 cancelledAssets
    ) external;
    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 scId,
        address user,
        uint128 assetId,
        uint128 fulfilledAssets,
        uint128 fulfilledShares,
        uint128 cancelledShares
    ) external;
    function balanceSheet() external view returns (address);
    function spoke() external view returns (address);
    function poolEscrow(uint64 poolId) external view returns (address);
}

interface IBalanceSheetLike {
    function deposit(uint64 poolId, bytes16 scId, address asset, uint256 tokenId, uint128 amount) external;
}

interface ISpokeLike {
    function assetToId(address asset, uint256 tokenId) external view returns (uint128);

    event InitiateTransferShares(
        uint16 centrifugeId,
        uint64 indexed poolId,
        bytes16 indexed scId,
        address indexed sender,
        bytes32 destinationAddress,
        uint128 amount
    );
}

abstract contract KeelLiquidityLayerTests is SpellRunner {
    function _getKeelLiquidityLayerContext(ChainId chain)
        internal
        view
        returns (KeelLiquidityLayerContext memory ctx)
    {
        if (chain == ChainIdUtils.Ethereum()) {
            ctx = KeelLiquidityLayerContext(
                Ethereum.ALM_CONTROLLER,
                IALMProxy(Ethereum.ALM_PROXY),
                IRateLimits(Ethereum.ALM_RATE_LIMITS),
                Ethereum.ALM_RELAYER,
                Ethereum.ALM_FREEZER
            );
        } else {
            revert("Chain not supported by KeelLiquidityLayerTests context");
        }
    }

    function _getKeelLiquidityLayerContext() internal view returns (KeelLiquidityLayerContext memory) {
        return _getKeelLiquidityLayerContext(ChainIdUtils.fromUint(block.chainid));
    }

    function _assertRateLimit(bytes32 key, uint256 maxAmount, uint256 slope) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getKeelLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, maxAmount);
        assertEq(rateLimit.slope, slope);
    }

    function _assertUnlimitedRateLimit(bytes32 key) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getKeelLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, type(uint256).max);
        assertEq(rateLimit.slope, 0);
    }

    function _assertZeroRateLimit(bytes32 key) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getKeelLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, 0);
        assertEq(rateLimit.slope, 0);
    }

    function _assertRateLimit(bytes32 key, uint256 maxAmount, uint256 slope, uint256 lastAmount, uint256 lastUpdated)
        internal
        view
    {
        IRateLimits.RateLimitData memory rateLimit = _getKeelLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, maxAmount);
        assertEq(rateLimit.slope, slope);
        assertEq(rateLimit.lastAmount, lastAmount);
        assertEq(rateLimit.lastUpdated, lastUpdated);
    }

    function _testERC4626Onboarding(
        address vault,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        KeelLiquidityLayerContext memory ctx = _getKeelLiquidityLayerContext();
        bool unlimitedDeposit = depositMax == type(uint256).max;

        // Note: ERC4626 signature is the same for mainnet and foreign
        deal(IERC4626(vault).asset(), address(ctx.proxy), expectedDepositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(KeelLiquidityLayerHelpers.LIMIT_4626_DEPOSIT, vault);
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(KeelLiquidityLayerHelpers.LIMIT_4626_WITHDRAW, vault);

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(withdrawKey);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        ctx = _getKeelLiquidityLayerContext();

        _assertRateLimit(depositKey, depositMax, depositSlope);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).depositERC4626(vault, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey), depositMax);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        assertEq(
            ctx.rateLimits.getCurrentRateLimit(depositKey),
            unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount
        );
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).withdrawERC4626(vault, expectedDepositAmount / 2);

        assertEq(
            ctx.rateLimits.getCurrentRateLimit(depositKey),
            unlimitedDeposit ? type(uint256).max : expectedDepositAmount / 2
        );
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        if (!unlimitedDeposit) {
            // Do some sanity checks on the slope
            // This is to catch things like forgetting to divide to a per-second time, etc

            // We assume it takes at least 1 day to recharge to max
            uint256 dailySlope = depositSlope * 1 days;
            assertLe(dailySlope, depositMax);

            // It shouldn"t take more than 30 days to recharge to max
            uint256 monthlySlope = depositSlope * 30 days;
            assertGe(monthlySlope, depositMax);
        }
    }
}
