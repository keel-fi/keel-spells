// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import "src/test-harness/KeelTestBase.sol";

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";
import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";
import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";
import {ChainIdUtils} from "src/libraries/ChainId.sol";

contract KeelEthereum_20260115Test is KeelTestBase {
    MainnetController internal controller = MainnetController(Ethereum.ALM_CONTROLLER);

    address internal constant KEEL_ETHEREUM_20260115 = 0x10AF705fB80bc115FCa83a6B976576Feb1E1aaca;

    constructor() {
        id = "20260115";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 24176770});
        chainData[ChainIdUtils.Ethereum()].payload = KEEL_ETHEREUM_20260115;
    }

    function test_cctpMintRecipientWasUpdated() public {
        assertEq(
            controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA),
            bytes32(Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY)
        );

        // Execute the payload
        executeAllPayloadsAndBridges();

        // Check that the CCTP mint recipient was updated (not zero)
        bytes32 recipient = controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);
        assertEq(recipient, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY_USDC_ATA, "cctp-mint-recipient-not-updated");

        uint256 usdcAmount = 10_000e6;
        uint256 usdcToCctpRateLimit = 100_000_000e6;
        uint256 solanaRateLimit = 100_000_000e6;

        bytes32 solanaKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA
        );

        IRateLimits rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDC_TO_CCTP()), usdcToCctpRateLimit);
        assertEq(rateLimits.getCurrentRateLimit(solanaKey), solanaRateLimit);

        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(usdcAmount * 1e12);
        controller.swapUSDSToUSDC(usdcAmount);

        // Transferring more than ratelimit fails
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.transferUSDCToCCTP(usdcToCctpRateLimit + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);

        controller.transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);
        vm.stopPrank();

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDC_TO_CCTP()), usdcToCctpRateLimit - usdcAmount);
        assertEq(rateLimits.getCurrentRateLimit(solanaKey), solanaRateLimit - usdcAmount);

        skip(1 days);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDC_TO_CCTP()), usdcToCctpRateLimit);
        assertEq(rateLimits.getCurrentRateLimit(solanaKey), solanaRateLimit);
    }
}
