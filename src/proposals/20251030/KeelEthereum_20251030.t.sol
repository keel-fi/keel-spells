// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/KeelTestBase.sol";

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

import {IALMProxy} from "lib/keel-alm-controller/src/interfaces/IALMProxy.sol";
import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";

import {AllocatorVault} from "lib/dss-allocator/src/AllocatorVault.sol";
import {AllocatorRoles} from "lib/dss-allocator/src/AllocatorRoles.sol";
import {AllocatorBuffer} from "lib/dss-allocator/src/AllocatorBuffer.sol";

import {KeelLiquidityLayerContext, CentrifugeConfig} from "../../test-harness/KeelLiquidityLayerTests.sol";

import {KeelEthereum_20251030} from "./KeelEthereum_20251030.sol";

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function kiss(address) external;
}

contract KeelEthereum_20251030Test is KeelTestBase {
    address internal constant SVM_CONTROLLER_AUTHORITY = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    uint32 internal constant SVM_CCTP_DESTINATION_ENDPOINT_ID = 5;
    uint32 internal constant SVM_LZ_DESTINATION_ENDPOINT_ID = 40168;

    IALMProxy almProxy = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = "20251030";
    }

    function setUp() public {
        setupDomain({mainnetForkBlock: 23392563});
        deployPayload(ChainIdUtils.Ethereum());

        vm.startPrank(Ethereum.PAUSE_PROXY);
        IPSMLike(address(controller.psm())).kiss(address(almProxy));

        // Keel is not currently the ilk admin nor does it have ownership
        // of the Allocator Vault and Buffer. Force Keel subproxy to have
        // ownership over these contracts until the approproate spell has
        // executed.
        AllocatorRoles(Ethereum.ALLOCATOR_ROLES).setIlkAdmin("ALLOCATOR-NOVA-A", Ethereum.KEEL_PROXY);
        AllocatorVault(Ethereum.ALLOCATOR_VAULT).rely(Ethereum.KEEL_PROXY);
        AllocatorVault(Ethereum.ALLOCATOR_VAULT).deny(Ethereum.PAUSE_PROXY);
        AllocatorBuffer(Ethereum.ALLOCATOR_BUFFER).rely(Ethereum.KEEL_PROXY);
        AllocatorBuffer(Ethereum.ALLOCATOR_BUFFER).deny(Ethereum.PAUSE_PROXY);
        vm.stopPrank();
    }

    function test_controllerConfiguration() public {
        assertEq(
            controller.mintRecipients(SVM_CCTP_DESTINATION_ENDPOINT_ID),
            bytes32(bytes20(uint160(0x0000000000000000000000000000000000000000)))
        );
        assertEq(
            controller.layerZeroRecipients(SVM_LZ_DESTINATION_ENDPOINT_ID),
            bytes32(bytes20(uint160(0x0000000000000000000000000000000000000000)))
        );

        executeAllPayloadsAndBridges();

        assertEq(
            controller.mintRecipients(SVM_CCTP_DESTINATION_ENDPOINT_ID),
            bytes32(bytes20(uint160(SVM_CONTROLLER_AUTHORITY)))
        );
        assertEq(
            controller.layerZeroRecipients(SVM_LZ_DESTINATION_ENDPOINT_ID),
            bytes32(bytes20(uint160(SVM_CONTROLLER_AUTHORITY)))
        );
    }
}
