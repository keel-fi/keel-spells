// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import "src/test-harness/KeelTestBase.sol";

import {CCTPForwarder} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";
import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";
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

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {KeelLiquidityLayerHelpers} from "src/libraries/KeelLiquidityLayerHelpers.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract MockCCTPTokenMinter {
    function burnLimitsPerMessage(address) external pure returns (uint256) {
        return type(uint256).max;
    }
}

contract MockCCTP {
    IERC20 public immutable usdc;
    address public immutable localMinterAddress;

    constructor(IERC20 _usdc, address _localMinterAddress) {
        usdc = _usdc;
        localMinterAddress = _localMinterAddress;
    }

    function localMinter() external view returns (address) {
        return localMinterAddress;
    }

    function depositForBurn(uint256 amount, uint32, bytes32, address token) external returns (uint64) {
        require(token == address(usdc), "MockCCTP/token-mismatch");
        require(usdc.transferFrom(msg.sender, address(this), amount), "MockCCTP/transfer-failed");
        return 1;
    }
}

contract MockOFT {
    IERC20 public immutable token;

    constructor(IERC20 _token) {
        token = _token;
    }

    function approvalRequired() external pure returns (bool) {
        return false;
    }

    function quoteOFT(SendParam calldata params)
        external
        pure
        returns (OFTLimit memory limit, OFTFeeDetail[] memory feeDetails, OFTReceipt memory receipt)
    {
        limit = OFTLimit({minAmountLD: 0, maxAmountLD: 0});
        feeDetails = new OFTFeeDetail[](0);
        receipt = OFTReceipt({amountSentLD: params.amountLD, amountReceivedLD: params.amountLD});
    }

    function quoteSend(SendParam calldata, bool) external pure returns (MessagingFee memory fee) {
        fee = MessagingFee({nativeFee: 0, lzTokenFee: 0});
    }

    function send(SendParam calldata params, MessagingFee calldata, address)
        external
        returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt)
    {
        require(token.transferFrom(msg.sender, address(this), params.amountLD), "MockOFT/transfer-failed");
        receipt = MessagingReceipt({guid: bytes32(0), nonce: 1, fee: MessagingFee({nativeFee: 0, lzTokenFee: 0})});
        oftReceipt = OFTReceipt({amountSentLD: params.amountLD, amountReceivedLD: params.amountLD});
    }
}

contract KeelEthereum_20251127Test is KeelTestBase {
    // https://docs.layerzero.network/v2/deployments/deployed-contracts?stages=mainnet&chains=solana
    uint32 internal constant SOLANA_LAYERZERO_DESTINATION = 30168;

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
        solanaLayerZeroKey = keccak256(
            abi.encode(
                controller.LIMIT_LAYERZERO_TRANSFER(), Ethereum.USDS_SKY_OFT_ADAPTER, SOLANA_LAYERZERO_DESTINATION
            )
        );
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
            Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY,
            "incorrect-cctp-recipient"
        );
        assertEq(
            controller.layerZeroRecipients(SOLANA_LAYERZERO_DESTINATION),
            Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY,
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
        MockCCTPTokenMinter mockTokenMinter = new MockCCTPTokenMinter();
        MockCCTP mockCctp = new MockCCTP(IERC20(address(controller.usdc())), address(mockTokenMinter));
        vm.etch(cctp, address(mockCctp).code);

        deal(address(controller.usdc()), Ethereum.ALM_PROXY, transferAmount);
        _assertMainnetAlmProxyBalances(0, transferAmount);

        assertEq(rateLimits.getCurrentRateLimit(generalCctpKey), TRANSFER_LIMIT_E6);
        assertEq(rateLimits.getCurrentRateLimit(solanaCctpKey), TRANSFER_LIMIT_E6);
        assertEq(
            controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA), Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        );

        uint256 cctpBalanceBefore = IERC20(address(controller.usdc())).balanceOf(cctp);

        vm.expectEmit(address(controller));
        emit CCTPLib.CCTPTransferInitiated(
            1, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA, Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY, transferAmount
        );

        vm.prank(Ethereum.ALM_RELAYER);
        controller.transferUSDCToCCTP(transferAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA);

        assertEq(rateLimits.getCurrentRateLimit(generalCctpKey), TRANSFER_LIMIT_E6 - transferAmount);
        assertEq(rateLimits.getCurrentRateLimit(solanaCctpKey), TRANSFER_LIMIT_E6 - transferAmount);
        _assertMainnetAlmProxyBalances(0, 0);
        assertEq(
            IERC20(address(controller.usdc())).balanceOf(cctp),
            cctpBalanceBefore + transferAmount,
            "incorrect-cctp-usdc-balance"
        );
    }

    function test_layerZeroBridgeToSolana() public {
        uint256 transferAmount = 1_000e18;

        vm.startPrank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.transferTokenLayerZero(Ethereum.USDS_SKY_OFT_ADAPTER, transferAmount, SOLANA_LAYERZERO_DESTINATION);
        vm.stopPrank();

        MockOFT mockOft = new MockOFT(IERC20(Ethereum.USDS));
        vm.etch(Ethereum.USDS_SKY_OFT_ADAPTER, address(mockOft).code);

        executeAllPayloadsAndBridges();

        uint256 oftBalanceBefore = IERC20(Ethereum.USDS).balanceOf(Ethereum.USDS_SKY_OFT_ADAPTER);
        assertEq(
            controller.layerZeroRecipients(SOLANA_LAYERZERO_DESTINATION), Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY
        );
        assertEq(rateLimits.getCurrentRateLimit(solanaLayerZeroKey), TRANSFER_LIMIT_E18);

        deal(Ethereum.USDS, Ethereum.ALM_PROXY, transferAmount);
        _assertMainnetAlmProxyBalances(transferAmount, 0);

        vm.prank(Ethereum.ALM_PROXY);
        IERC20(Ethereum.USDS).approve(Ethereum.USDS_SKY_OFT_ADAPTER, transferAmount);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.transferTokenLayerZero(Ethereum.USDS_SKY_OFT_ADAPTER, transferAmount, SOLANA_LAYERZERO_DESTINATION);

        assertEq(rateLimits.getCurrentRateLimit(solanaLayerZeroKey), TRANSFER_LIMIT_E18 - transferAmount);
        _assertMainnetAlmProxyBalances(0, 0);
        assertEq(
            IERC20(Ethereum.USDS).balanceOf(Ethereum.USDS_SKY_OFT_ADAPTER),
            oftBalanceBefore + transferAmount,
            "incorrect-usds-oft-balance"
        );
    }
}
