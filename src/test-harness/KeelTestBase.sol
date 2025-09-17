// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {KeelLiquidityLayerTests} from "./KeelLiquidityLayerTests.sol";
import {CommonSpellAssertions} from "./CommonSpellAssertions.sol";
import {CommonTestBase} from "./CommonTestBase.sol";
import {ChainIdUtils} from "../libraries/ChainId.sol";
import {Ethereum} from "keel-address-registry/Ethereum.sol";
import {DomainHelpers} from "xchain-helpers/testing/Domain.sol";

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specific test contracts
contract KeelTestBase is CommonTestBase, CommonSpellAssertions, KeelLiquidityLayerTests {
    function setUp() public virtual {
        // Set up domains with static block numbers for testing
        // Using a recent mainnet block number instead of making API calls
        chainData[ChainIdUtils.Ethereum()].domain = DomainHelpers.createFork(getChain("mainnet"), 21000000);
        
        // We default to Ethereum domain
        DomainHelpers.selectFork(chainData[ChainIdUtils.Ethereum()].domain);
        
        chainData[ChainIdUtils.Ethereum()].prevController = Ethereum.ALM_CONTROLLER;
        chainData[ChainIdUtils.Ethereum()].newController = Ethereum.ALM_CONTROLLER;
        
        // Register chains
        allChains.push(ChainIdUtils.Ethereum());
    }
}
