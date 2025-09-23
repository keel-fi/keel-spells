// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/KeelTestBase.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {RateLimitHelpers} from "lib/keel-alm-controller/src/RateLimitHelpers.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

import {IALMProxy} from "lib/keel-alm-controller/src/interfaces/IALMProxy.sol";
import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";

import {AllocatorVault} from "lib/dss-allocator/src/AllocatorVault.sol";
import {AllocatorRoles} from "lib/dss-allocator/src/AllocatorRoles.sol";
import {AllocatorBuffer} from "lib/dss-allocator/src/AllocatorBuffer.sol";

import {KeelLiquidityLayerContext, CentrifugeConfig} from "../../test-harness/KeelLiquidityLayerTests.sol";

import {KeelEthereum_20251002} from "./KeelEthereum_20251002.sol";

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function kiss(address) external;
}

contract KeelEthereum_20251002Test is KeelTestBase {
    address internal DEPLOYER;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-NOVA-A";

    IALMProxy almProxy = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = "20251002";
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

    function test_almSystemDeployment() public view {
        assertEq(almProxy.hasRole(0x0, Ethereum.KEEL_PROXY), true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Ethereum.KEEL_PROXY), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Ethereum.KEEL_PROXY), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER), false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()), Ethereum.ALM_PROXY, "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), Ethereum.ALM_RATE_LIMITS, "incorrect-rateLimits");
        assertEq(address(controller.vault()), Ethereum.ALLOCATOR_VAULT, "incorrect-vault");
        assertEq(address(controller.buffer()), Ethereum.ALLOCATOR_BUFFER, "incorrect-buffer");
        assertEq(address(controller.psm()), Ethereum.PSM, "incorrect-psm");
        assertEq(address(controller.daiUsds()), Ethereum.DAI_USDS, "incorrect-daiUsds");
        assertEq(address(controller.cctp()), Ethereum.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.dai()), Ethereum.DAI, "incorrect-dai");
        assertEq(address(controller.susde()), Ethereum.SUSDE, "incorrect-susde");
        assertEq(address(controller.ustb()), Ethereum.USTB, "incorrect-ustb");
        assertEq(address(controller.usdc()), Ethereum.USDC, "incorrect-usdc");
        assertEq(address(controller.usde()), Ethereum.USDE, "incorrect-usde");
        assertEq(address(controller.usds()), Ethereum.USDS, "incorrect-usds");

        assertEq(controller.psmTo18ConversionFactor(), 1e12, "incorrect-psmTo18ConversionFactor");

        IVatLike vat = IVatLike(Ethereum.VAT);

        (uint256 Art, uint256 rate,, uint256 line,) = vat.ilks(ALLOCATOR_ILK);

        assertEq(Art, 0);
        assertEq(rate, 1e27);
        assertEq(line, 1_000_000e45);

        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.KEEL_PROXY), 0);
    }

    function test_almSystemInitialization() public {
        executeAllPayloadsAndBridges();

        assertEq(
            almProxy.hasRole(almProxy.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-almProxy"
        );

        assertEq(
            rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER),
            true,
            "incorrect-controller-rateLimits"
        );

        assertEq(controller.hasRole(controller.FREEZER(), Ethereum.ALM_FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), Ethereum.ALM_RELAYER), true, "incorrect-relayer-controller");

        assertEq(AllocatorVault(Ethereum.ALLOCATOR_VAULT).wards(Ethereum.ALM_PROXY), 1, "incorrect-vault-ward");

        assertEq(
            IERC20(Ethereum.USDS).allowance(Ethereum.ALLOCATOR_BUFFER, Ethereum.ALM_PROXY),
            type(uint256).max,
            "incorrect-usds-allowance"
        );
    }

    function test_basicRateLimits() public {
        _assertRateLimit({key: controller.LIMIT_USDS_MINT(), maxAmount: 0, slope: 0});

        _assertRateLimit({key: controller.LIMIT_USDS_TO_USDC(), maxAmount: 0, slope: 0});

        executeAllPayloadsAndBridges();

        uint256 mintAndBurnAmount = 5_000e18;
        uint256 swapAmount = 5_000e6;

        vm.prank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(mintAndBurnAmount);
        vm.prank(Ethereum.ALM_RELAYER);
        controller.swapUSDSToUSDC(swapAmount);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDS_MINT()), 5_000e18);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDS_TO_USDC()), 5_000e6);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.swapUSDCToUSDS(swapAmount);
        vm.prank(Ethereum.ALM_RELAYER);
        controller.burnUSDS(mintAndBurnAmount);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDS_MINT()), 10_000e18);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDS_TO_USDC()), 10_000e6);

        _assertRateLimit({key: controller.LIMIT_USDS_MINT(), maxAmount: 10_000e18, slope: 5_000e18 / uint256(1 days)});
        _assertRateLimit({key: controller.LIMIT_USDS_TO_USDC(), maxAmount: 10_000e6, slope: 5_000e6 / uint256(1 days)});
    }

    function test_susdsVaultOnboarding() public {
        _testERC4626Onboarding(Ethereum.SUSDS, 10_000e18, 10_000e18, 5_000e18 / uint256(1 days));
    }
}
