// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, KeelPayloadEthereum } from "src/libraries/KeelPayloadEthereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/sky-star-alm-controller/deploy/MainnetControllerInit.sol";

import { MainnetController } from "lib/sky-star-alm-controller/src/MainnetController.sol";

/**
 * @title  September 15, 2025 Keel Ethereum Proposal
 * @notice Activate Keel Liquidity Layer - initiate ALM system, set rate limits, onboard Centrifuge Vault
 * @author Exo Tech
 * Forum: TODO
 * Vote:  TODO -- Increase line and gap
 *        TODO -- Activate Liquidity Layer
 */
contract KeelEthereum_20250915 is KeelPayloadEthereum{

    function _execute() internal override {
        _initiateAlmSystem();
        _setupBasicRateLimits();
    }

    function _initiateAlmSystem() internal {
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);
        MainnetControllerInit.LayerZeroRecipient[] memory layerZeroRecipients = new MainnetControllerInit.LayerZeroRecipient[](0);

        MainnetControllerInit.initAlmSystem({
            vault: Ethereum.ALLOCATOR_VAULT,
            usds: Ethereum.USDS,
            controllerInst: ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : Ethereum.ALM_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            configAddresses: MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayers       : _createRelayersArray(),
                oldController : address(0)
            }),
            checkAddresses: MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.SPARK_PROXY, // TODO: change to KEEL_PROXY
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients: mintRecipients,
            layerZeroRecipients: layerZeroRecipients
        });
    }


    function _setupBasicRateLimits() private {
    }

    function _createRelayersArray() private pure returns (address[] memory) {
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;
        return relayers;
    }

}
