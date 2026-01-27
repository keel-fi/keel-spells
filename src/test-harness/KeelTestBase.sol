// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {KeelLiquidityLayerTests} from "./KeelLiquidityLayerTests.sol";
import {CommonSpellAssertions} from "./CommonSpellAssertions.sol";
import {CommonTestBase} from "./CommonTestBase.sol";

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specific test contracts
abstract contract KeelTestBase is CommonTestBase, CommonSpellAssertions, KeelLiquidityLayerTests {
    /**
     * @dev Convenience method to capture LayerZero payloads with default settings
     * @return filePaths Array of file paths where payloads were saved
     * @return payloads Array of extracted message payloads
     * @notice Call startCaptureLayerZeroPayloads() before executeAllPayloadsAndBridges()
     */
    function captureLayerZeroPayloads() internal returns (string[] memory filePaths, bytes[] memory payloads) {
        return captureLayerZeroPayloads(address(0), "");
    }

    /**
     * @dev Convenience method to capture LayerZero payloads with custom EndpointV2 address
     * @param endpointV2 Address of LayerZero EndpointV2 contract (use address(0) for default)
     * @return filePaths Array of file paths where payloads were saved
     * @return payloads Array of extracted message payloads
     * @notice Call startCaptureLayerZeroPayloads() before executeAllPayloadsAndBridges()
     */
    function captureLayerZeroPayloads(address endpointV2)
        internal
        returns (string[] memory filePaths, bytes[] memory payloads)
    {
        return captureLayerZeroPayloads(endpointV2, "");
    }
}
