// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {IALMProxy} from "lib/keel-alm-controller/src/interfaces/IALMProxy.sol";
import {IRateLimits} from "lib/keel-alm-controller/src/interfaces/IRateLimits.sol";

import {ForeignController} from "lib/keel-alm-controller/src/ForeignController.sol";
import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

import {CCTPReceiver} from "lib/xchain-helpers/src/receivers/CCTPReceiver.sol";

import {ChainIdUtils, ChainId} from "../libraries/ChainId.sol";

import {SpellRunner} from "./SpellRunner.sol";

abstract contract CommonSpellAssertions is SpellRunner {
    function test_ETHEREUM_PayloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches(ChainIdUtils.Ethereum());
    }

    function test_ETHEREUM_ExecutionCost() public {
        uint256 startGas = gasleft();
        executeAllPayloadsAndBridges();
        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;

        // Warn if deploy exceeds block target size
        if (totalGas > 15_000_000) {
            emit log("Warn: deploy gas exceeds average block target");
            emit log_named_uint("    deploy gas", totalGas);
            emit log_named_uint("  block target", 15_000_000);
        }

        // Fail if deploy is too expensive
        assertLe(totalGas, 30_000_000, "TestError/spell-deploy-cost-too-high");
    }

    function _assertPayloadBytecodeMatches(ChainId chainId) private onChain(chainId) {
        address actualPayload = chainData[chainId].payload;
        vm.skip(actualPayload == address(0));
        require(_isContract(actualPayload), "PAYLOAD IS NOT A CONTRACT");
        address expectedPayload = deployPayload(chainId);

        uint256 expectedBytecodeSize = expectedPayload.code.length;
        uint256 actualBytecodeSize = actualPayload.code.length;

        uint256 metadataLength = _getBytecodeMetadataLength(expectedPayload);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = _getBytecodeMetadataLength(actualPayload);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);

        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;

        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedPayload, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualPayload, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }

        assertEq(actualHash, expectedHash);
    }

    function _getBytecodeMetadataLength(address a) internal view returns (uint256 length) {
        // The Solidity compiler encodes the metadata length in the last two bytes of the contract bytecode.
        assembly {
            let ptr := mload(0x40)
            let size := extcodesize(a)
            if iszero(lt(size, 2)) {
                extcodecopy(a, ptr, sub(size, 2), 2)
                length := mload(ptr)
                length := shr(240, length)
                length := add(length, 2) // The two bytes used to specify the length are not counted in the length
            }
            // Return zero if the bytecode is shorter than two bytes.
        }
    }

    /**
     * @notice Asserts the USDS and USDC balances of the ALM proxy
     * @param usds The expected USDS balance
     * @param usdc The expected USDC balance
     */
    function _assertMainnetAlmProxyBalances(uint256 usds, uint256 usdc) internal view {
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.ALM_PROXY), usds, "incorrect-alm-proxy-usds-balance");
        assertEq(IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY), usdc, "incorrect-alm-proxy-usdc-balance");
    }

    struct AlmSystemContracts {
        address admin;
        address proxy;
        address rateLimits;
        address controller;
    }

    struct AlmSystemActors {
        address deployer;
        address freezer;
        address relayer;
    }

    struct ForeignAlmSystemDependencies {
        address psm;
        address usdc;
        address cctp;
    }

    struct MainnetAlmSystemDependencies {
        address vault;
        address psm;
        address daiUsds;
        address cctp;
    }

    function _verifyMainnetControllerDeployment(
        AlmSystemContracts memory contracts,
        AlmSystemActors memory actors,
        MainnetAlmSystemDependencies memory dependencies
    ) internal view {
        MainnetController controller = MainnetController(contracts.controller);

        // All contracts have admin as admin set in constructor
        assertEq(controller.hasRole(0x0, contracts.admin), true, "incorrect-admin-controller");

        // No roles other than admin as admin are set before the initialization (checking for EOA and multisig wallets)
        assertEq(controller.hasRole(0x0, actors.deployer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0, actors.relayer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0, actors.freezer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.deployer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.freezer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.relayer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.deployer), false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.freezer), false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.relayer), false, "incorrect-relayer-controller");

        // Controller has correct proxy, rate limits, psm, usdc, and cctp messenger
        assertEq(address(controller.proxy()), contracts.proxy, "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), contracts.rateLimits, "incorrect-rateLimits");
        assertEq(address(controller.vault()), dependencies.vault, "incorrect-vault");
        assertEq(address(controller.psm()), dependencies.psm, "incorrect-psm");
        assertEq(address(controller.daiUsds()), dependencies.daiUsds, "incorrect-daiUsds");
        assertEq(address(controller.cctp()), dependencies.cctp, "incorrect-cctp");
    }

    function _verifyForeignControllerDeployment(
        AlmSystemContracts memory contracts,
        AlmSystemActors memory actors,
        ForeignAlmSystemDependencies memory dependencies
    ) internal view {
        ForeignController controller = ForeignController(contracts.controller);

        // All contracts have admin as admin set in constructor
        assertEq(controller.hasRole(0x0, contracts.admin), true, "incorrect-admin-controller");

        // No roles other than admin as admin are set before the initialization (checking for EOA and multisig wallets)
        assertEq(controller.hasRole(0x0, actors.deployer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0, actors.relayer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(0x0, actors.freezer), false, "incorrect-admin-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.deployer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.freezer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.FREEZER(), actors.relayer), false, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.deployer), false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.freezer), false, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), actors.relayer), false, "incorrect-relayer-controller");

        // Controller has correct proxy, rate limits, psm, usdc, and cctp messenger
        assertEq(address(controller.proxy()), contracts.proxy, "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), contracts.rateLimits, "incorrect-rateLimits");
        assertEq(address(controller.psm()), dependencies.psm, "incorrect-psm");
        assertEq(address(controller.usdc()), dependencies.usdc, "incorrect-usdc");
        assertEq(address(controller.cctp()), dependencies.cctp, "incorrect-cctp");
    }

    function _verifyForeignAlmSystemDeployment(
        AlmSystemContracts memory contracts,
        AlmSystemActors memory actors,
        ForeignAlmSystemDependencies memory dependencies
    ) internal view {
        IALMProxy almProxy = IALMProxy(contracts.proxy);
        IRateLimits rateLimits = IRateLimits(contracts.rateLimits);

        // All contracts have admin as admin set in constructor
        assertEq(almProxy.hasRole(0x0, contracts.admin), true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, contracts.admin), true, "incorrect-admin-rateLimits");

        // No roles other than admin as admin are set before the initialization in the proxy
        assertEq(almProxy.hasRole(0x0, actors.deployer), false, "incorrect-admin-almProxy");
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), actors.deployer), false, "incorrect-controller-almProxy");
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), contracts.controller), false, "incorrect-controller-almProxy");

        // No roles other than admin as admin are set before the initialization in the rate limits
        assertEq(rateLimits.hasRole(0x0, actors.deployer), false, "incorrect-admin-rateLimits");
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), actors.deployer), false, "incorrect-controller-rateLimits");
        assertEq(
            rateLimits.hasRole(rateLimits.CONTROLLER(), contracts.controller), false, "incorrect-controller-rateLimits"
        );

        _verifyForeignControllerDeployment(contracts, actors, dependencies);
    }

    function _verifyCctpReceiverDeployment(address _executor, address _receiver, address _cctpMessageTransmitter)
        internal
        view
    {
        CCTPReceiver receiver = CCTPReceiver(_receiver);

        // Receiver's destination messenger has to be the local cctp messenger
        assertEq(receiver.destinationMessenger(), _cctpMessageTransmitter, "incorrect-cctp-transmitter");

        // Source domain id has to be always Ethereum Mainnet id
        assertEq(receiver.sourceDomainId(), 0, "incorrect-source-domain-id");

        // Source authority has to be the Ethereum Mainnet Keel Proxy
        assertEq(
            receiver.sourceAuthority(), bytes32(uint256(uint160(Ethereum.KEEL_PROXY))), "incorrect-source-authority"
        );

        // Target has to be the executor
        assertEq(receiver.target(), _executor, "incorrect-target");
    }
}
