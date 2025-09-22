// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {MainnetControllerInit, ControllerInstance} from "lib/keel-alm-controller/deploy/MainnetControllerInit.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

/**
 * @title  October 02, 2025 Keel Ethereum Proposal
 * @notice Activate Keel Liquidity Layer
 *             - Add CONTROLLER to ALMProxy
 *             - Add CONTROLLER to RateLimits
 *             - Add FREEZER to ALMController
 *             - Add RELAYER to ALMController
 *             - Add ALMProxy to AllocatorVault wards
 *             - Add infinite approval for USDS transfer from AllocatorBuffer for ALMProxy
 *         Set basic Keel Liquidity Layer rate limits
 *             - Set USDS minting rate limit
 *             - Set USDS to USDC PSM swapping rate limit
 *             - Set sUSDS Deposit/Withdraw rate limit
 * @author Exo Tech
 * Forum: TODO
 * Vote:  TODO -- Increase line and gap
 *        TODO -- Activate Liquidity Layer
 */
contract KeelEthereum_20251002 is KeelPayloadEthereum {

    address internal constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

    function _execute() internal override {
        _initiateAlmSystem();
        _setupBasicRateLimits();
        _onboardSusdsVault();
    }

    function _initiateAlmSystem() internal {
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);
        MainnetControllerInit.LayerZeroRecipient[] memory layerZeroRecipients =
            new MainnetControllerInit.LayerZeroRecipient[](0);
        MainnetControllerInit.MaxSlippageParams[] memory maxSlippageParams =
            new MainnetControllerInit.MaxSlippageParams[](0);

        MainnetControllerInit.initAlmSystem({
            vault: Ethereum.ALLOCATOR_VAULT,
            usds: Ethereum.USDS,
            controllerInst: ControllerInstance({
                almProxy: Ethereum.ALM_PROXY,
                controller: Ethereum.ALM_CONTROLLER,
                rateLimits: Ethereum.ALM_RATE_LIMITS
            }),
            configAddresses: MainnetControllerInit.ConfigAddressParams({
                freezer: Ethereum.ALM_FREEZER,
                relayers: _createRelayersArray(),
                oldController: address(0)
            }),
            checkAddresses: MainnetControllerInit.CheckAddressParams({
                admin: Ethereum.KEEL_PROXY,
                proxy: Ethereum.ALM_PROXY,
                rateLimits: Ethereum.ALM_RATE_LIMITS,
                vault: Ethereum.ALLOCATOR_VAULT,
                psm: Ethereum.PSM,
                daiUsds: Ethereum.DAI_USDS,
                cctp: Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients: mintRecipients,
            layerZeroRecipients: layerZeroRecipients,
            maxSlippageParams: maxSlippageParams
        });
    }

    function _setupBasicRateLimits() private {
        // Update USDS RateLimit
        // before: 0
        // After: 10k
        _setUSDSMintRateLimit(10_000e18, 5_000e18 / uint256(1 days));
        
        // Update USDS <> USDC RateLimit
        // before: 0
        // After: 10k
        _setUSDSToUSDCRateLimit(10_000e6, 5_000e6 / uint256(1 days));
    }

    function _onboardSusdsVault() private {
        // Update sUSDS RateLimit
        // before: 0
        // After: 10k
        _onboardERC4626Vault(
            SUSDS,
            10_000e18,
            5_000e18 / uint256(1 days)
        );
    }

    function _createRelayersArray() private pure returns (address[] memory) {
        address[] memory relayers = new address[](2);
        relayers[0] = Ethereum.ALM_RELAYER;
        // Keel Relayer C (Backup)
        relayers[1] = 0x0f72935f6de6C54Ce8056FD040d4Ddb012B7cd54;
        return relayers;
    }
}
