// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import "src/test-harness/KeelTestBase.sol";

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {KeelLiquidityLayerHelpers} from "src/libraries/KeelLiquidityLayerHelpers.sol";
import {KeelEthereum_20251127} from "./KeelEthereum_20251127.sol";

contract KeelEthereum_20251127Test is KeelTestBase {
    uint32 internal constant SOLANA_LAYERZERO_DESTINATION = 30168;
    bytes32 internal constant SOLANA_RECIPIENT = 0xcac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac48609;

    uint256 internal constant USDS_TO_USDC_LIMIT = 100_000_000e6;
    uint256 internal constant USDS_TO_USDC_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant SUSDS_DEPOSIT_LIMIT = 100_000_000e18;
    uint256 internal constant SUSDS_DEPOSIT_SLOPE = 50_000_000e18 / uint256(1 days);

    MainnetController internal controller = MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = "20251127";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 23184872});
        deployPayload(ChainIdUtils.Ethereum());
    }

    function test_rateLimitsAreUpdated() public {
        bytes32 usdsToUsdcKey = controller.LIMIT_USDS_TO_USDC();
        bytes32 generalCctpKey = controller.LIMIT_USDC_TO_CCTP();
        bytes32 solanaCctpKey =
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);
        bytes32 solanaLayerZeroKey =
            keccak256(abi.encode(controller.LIMIT_LAYERZERO_TRANSFER(), Ethereum.USDS, SOLANA_LAYERZERO_DESTINATION));
        bytes32 susdsDepositKey =
            RateLimitHelpers.makeAssetKey(KeelLiquidityLayerHelpers.LIMIT_4626_DEPOSIT, Ethereum.SUSDS);
        bytes32 susdsWithdrawKey =
            RateLimitHelpers.makeAssetKey(KeelLiquidityLayerHelpers.LIMIT_4626_WITHDRAW, Ethereum.SUSDS);

        // Sanity check pre-spell state
        _assertRateLimit(usdsToUsdcKey, 10_000e6, 5_000e6 / uint256(1 days));
        _assertRateLimit(generalCctpKey, 0, 0);
        _assertRateLimit(solanaCctpKey, 0, 0);
        _assertRateLimit(solanaLayerZeroKey, 0, 0);
        _assertRateLimit(susdsDepositKey, 10_000e18, 5_000e18 / uint256(1 days));
        _assertRateLimit(susdsWithdrawKey, type(uint256).max, 0);

        executeAllPayloadsAndBridges();

        _assertRateLimit(usdsToUsdcKey, USDS_TO_USDC_LIMIT, USDS_TO_USDC_SLOPE);
        _assertRateLimit(generalCctpKey, USDS_TO_USDC_LIMIT, USDS_TO_USDC_SLOPE);
        _assertRateLimit(solanaCctpKey, USDS_TO_USDC_LIMIT, USDS_TO_USDC_SLOPE);
        _assertRateLimit(solanaLayerZeroKey, SUSDS_DEPOSIT_LIMIT, SUSDS_DEPOSIT_SLOPE);
        _assertRateLimit(susdsDepositKey, SUSDS_DEPOSIT_LIMIT, SUSDS_DEPOSIT_SLOPE);
        _assertRateLimit(susdsWithdrawKey, type(uint256).max, 0);
    }

    function test_recipientsAreUpdated() public {
        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA), bytes32(0));
        assertEq(controller.layerZeroRecipients(SOLANA_LAYERZERO_DESTINATION), bytes32(0));

        executeAllPayloadsAndBridges();

        assertEq(
            controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA),
            SOLANA_RECIPIENT,
            "incorrect-cctp-recipient"
        );
        assertEq(
            controller.layerZeroRecipients(SOLANA_LAYERZERO_DESTINATION),
            SOLANA_RECIPIENT,
            "incorrect-layerzero-recipient"
        );
    }
}
