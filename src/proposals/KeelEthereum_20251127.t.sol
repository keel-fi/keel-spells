// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import "src/test-harness/KeelTestBase.sol";

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";
import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";
import {ICCTPLike, ICCTPTokenMinterLike} from "lib/keel-alm-controller/src/interfaces/CCTPInterfaces.sol";
import {CCTPLib} from "lib/keel-alm-controller/src/libraries/CCTPLib.sol";
import {
    ILayerZero,
    MessagingFee,
    MessagingReceipt,
    OFTFeeDetail,
    OFTLimit,
    OFTReceipt,
    SendParam
} from "lib/keel-alm-controller/src/interfaces/ILayerZero.sol";
import {OptionsBuilder} from "layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {KeelLiquidityLayerHelpers} from "src/libraries/KeelLiquidityLayerHelpers.sol";

contract KeelEthereum_20251127Test is KeelTestBase {
    using OptionsBuilder for bytes;

    // https://docs.layerzero.network/v2/deployments/deployed-contracts?stages=mainnet&chains=solana
    uint32 internal constant SOLANA_LAYERZERO_DESTINATION = 30168;
    // This was calculated by decoding the Solana base58 address `EeWDutgcKNTdQGJkGRrWYmTXXuKnPUZNvXepbLkQrxW4` into hex
    bytes32 internal constant SOLANA_RECIPIENT = 0xcac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac48609;
    address internal constant USDS_OFT = 0x1e1D42781FC170EF9da004Fb735f56F0276d01B8;

    uint256 internal constant TRANSFER_LIMIT_E6 = 100_000_000e6;
    uint256 internal constant TRANSFER_SLOPE_E6 = 50_000_000e6 / uint256(1 days);

    uint256 internal constant TRANSFER_LIMIT_E18 = 100_000_000e18;
    uint256 internal constant TRANSFER_SLOPE_E18 = 50_000_000e18 / uint256(1 days);

    MainnetController internal controller = MainnetController(Ethereum.ALM_CONTROLLER);
    IRateLimits internal rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);

    bytes32 internal generalCctpKey;
    bytes32 internal solanaCctpKey;
    bytes32 internal solanaLayerZeroKey;

    constructor() {
        id = "20251127";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 23784468});
        deployPayload(ChainIdUtils.Ethereum());

        generalCctpKey = controller.LIMIT_USDC_TO_CCTP();
        solanaCctpKey =
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);
        solanaLayerZeroKey =
            keccak256(abi.encode(controller.LIMIT_LAYERZERO_TRANSFER(), USDS_OFT, SOLANA_LAYERZERO_DESTINATION));
    }

    function test_rateLimitsAreUpdated() public {
        bytes32 usdsToUsdcKey = controller.LIMIT_USDS_TO_USDC();
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

        _assertRateLimit(usdsToUsdcKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);
        _assertRateLimit(generalCctpKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);
        _assertRateLimit(solanaCctpKey, TRANSFER_LIMIT_E6, TRANSFER_SLOPE_E6);
        _assertRateLimit(solanaLayerZeroKey, TRANSFER_LIMIT_E18, TRANSFER_SLOPE_E18);
        _assertRateLimit(susdsDepositKey, TRANSFER_LIMIT_E18, TRANSFER_SLOPE_E18);
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

    function test_cctpBridgeToSolana() public {
        uint256 transferAmount = 1_000e6;

        vm.startPrank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.transferUSDCToCCTP(transferAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);
        vm.stopPrank();

        executeAllPayloadsAndBridges();

        address cctp = address(controller.cctp());
        address localMinter = address(0xBEEF);

        vm.mockCall(cctp, abi.encodeWithSelector(ICCTPLike.localMinter.selector), abi.encode(localMinter));
        vm.mockCall(
            localMinter,
            abi.encodeWithSelector(ICCTPTokenMinterLike.burnLimitsPerMessage.selector, address(controller.usdc())),
            abi.encode(type(uint256).max)
        );
        vm.mockCall(
            cctp,
            abi.encodeWithSelector(
                ICCTPLike.depositForBurn.selector,
                transferAmount,
                CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA,
                SOLANA_RECIPIENT,
                address(controller.usdc())
            ),
            abi.encode(uint64(1))
        );

        deal(address(controller.usdc()), Ethereum.ALM_PROXY, transferAmount);

        assertEq(rateLimits.getCurrentRateLimit(generalCctpKey), TRANSFER_LIMIT_E6);
        assertEq(rateLimits.getCurrentRateLimit(solanaCctpKey), TRANSFER_LIMIT_E6);
        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA), SOLANA_RECIPIENT);

        vm.expectEmit(address(controller));
        emit CCTPLib.CCTPTransferInitiated(1, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, SOLANA_RECIPIENT, transferAmount);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.transferUSDCToCCTP(transferAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);

        assertEq(rateLimits.getCurrentRateLimit(generalCctpKey), TRANSFER_LIMIT_E6 - transferAmount);
        assertEq(rateLimits.getCurrentRateLimit(solanaCctpKey), TRANSFER_LIMIT_E6 - transferAmount);
    }

    function test_layerZeroBridgeToSolana() public {
        uint256 transferAmount = 1_000e18;

        vm.startPrank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.transferTokenLayerZero(USDS_OFT, transferAmount, SOLANA_LAYERZERO_DESTINATION);
        vm.stopPrank();

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);

        SendParam memory postQuoteParams = SendParam({
            dstEid: SOLANA_LAYERZERO_DESTINATION,
            to: SOLANA_RECIPIENT,
            amountLD: transferAmount,
            minAmountLD: 0,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        SendParam memory postSendParams = postQuoteParams;
        postSendParams.minAmountLD = transferAmount;

        OFTLimit memory limit;
        OFTFeeDetail[] memory feeDetails = new OFTFeeDetail[](0);
        OFTReceipt memory receipt = OFTReceipt({amountSentLD: transferAmount, amountReceivedLD: transferAmount});
        MessagingFee memory fee = MessagingFee({nativeFee: 0, lzTokenFee: 0});
        MessagingReceipt memory msgReceipt = MessagingReceipt({guid: bytes32(0), nonce: 1, fee: fee});

        vm.mockCall(USDS_OFT, abi.encodeWithSelector(ILayerZero.approvalRequired.selector), abi.encode(false));
        vm.mockCall(
            USDS_OFT,
            abi.encodeWithSelector(ILayerZero.quoteOFT.selector, postQuoteParams),
            abi.encode(limit, feeDetails, receipt)
        );
        vm.mockCall(
            USDS_OFT, abi.encodeWithSelector(ILayerZero.quoteSend.selector, postSendParams, false), abi.encode(fee)
        );
        vm.mockCall(
            USDS_OFT,
            abi.encodeWithSelector(ILayerZero.send.selector, postSendParams, fee, Ethereum.ALM_PROXY),
            abi.encode(msgReceipt, receipt)
        );

        executeAllPayloadsAndBridges();

        assertEq(controller.layerZeroRecipients(SOLANA_LAYERZERO_DESTINATION), SOLANA_RECIPIENT);
        assertEq(rateLimits.getCurrentRateLimit(solanaLayerZeroKey), TRANSFER_LIMIT_E18);

        deal(Ethereum.USDS, Ethereum.ALM_PROXY, transferAmount);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.transferTokenLayerZero(USDS_OFT, transferAmount, SOLANA_LAYERZERO_DESTINATION);

        assertEq(rateLimits.getCurrentRateLimit(solanaLayerZeroKey), TRANSFER_LIMIT_E18 - transferAmount);
    }
}
