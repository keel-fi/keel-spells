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
        // Check that the CCTP mint recipient is initially zero
        assertEq(
            controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA),
            bytes32(0xcac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac48609)
        );

        // Execute the payload
        executeAllPayloadsAndBridges();

        // Check that the CCTP mint recipient was updated (not zero)
        bytes32 recipient = controller.mintRecipients(
            CCTPForwarder.DOMAIN_ID_CIRCLE_SOLANA
        );
        assertEq(recipient, "TODO" , "cctp-mint-recipient-not-updated");
    }
}
