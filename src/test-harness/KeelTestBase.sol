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
abstract contract KeelTestBase is CommonTestBase, CommonSpellAssertions, KeelLiquidityLayerTests {}
