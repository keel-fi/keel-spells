// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/KeelTestBase.sol";

import {
    CCTPForwarder
} from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import {
    RateLimitHelpers
} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";
import {
    MainnetController
} from "lib/keel-alm-controller/src/MainnetController.sol";
import {
    IRateLimits
} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";
import {CCTPLib} from "lib/keel-alm-controller/src/libraries/CCTPLib.sol";
import {
    MessagingFee,
    MessagingReceipt,
    OFTFeeDetail,
    OFTLimit,
    OFTReceipt,
    SendParam
} from "lib/keel-alm-controller/src/interfaces/ILayerZero.sol";

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {
    KeelLiquidityLayerHelpers
} from "src/libraries/KeelLiquidityLayerHelpers.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {KeelEthereum_20260115} from "./KeelEthereum_20260115.sol";

contract KeelEthereum_20260115Test is KeelTestBase {
    MainnetController internal controller =
        MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = "20260115";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 24026112});
        deployPayload(ChainIdUtils.Ethereum());
        // Fund KEEL_PROXY (SubProxy) with ETH to pay for LayerZero messaging fees
        vm.deal(Ethereum.KEEL_PROXY, 1 ether);
    }

    function test_cctpMintRecipientWasUpdated() public {
        assertEq(
            controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA),
            bytes32(Ethereum.KEEL_SVM_ALM_CONTROLLER_AUTHORITY)
        );

        // Execute the payload
        executeAllPayloadsAndBridges();

        // Check that the CCTP mint recipient was updated (not zero)
        bytes32 recipient = controller.mintRecipients(
            CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA
        );
        // TODO: move to the keel address registry
        assertEq(
            recipient,
            0x3387f134e4a16b92ee3cb364cbca054a8ec384932b537620588263ec760e6b40,
            "cctp-mint-recipient-not-updated"
        );
    }
}
