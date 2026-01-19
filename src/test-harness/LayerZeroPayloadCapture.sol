// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

/**
 * @title LayerZeroPayloadCapture
 * @dev Library for capturing LayerZero PacketSent events and saving encoded payloads
 * @notice Captures PacketSent events from EndpointV2 and saves full encoded payloads to files
 */
library LayerZeroPayloadCapture {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Event topic for PacketSent(bytes,bytes,address)
    bytes32 private constant PACKET_SENT_TOPIC = keccak256("PacketSent(bytes,bytes,address)");

    /// @dev Default LayerZero EndpointV2 address on Ethereum mainnet
    address private constant DEFAULT_ENDPOINT_V2 = 0x1a44076050125825900e736c501f859c50fE728c;

    /// @dev Default output directory for payload files
    /// @notice Uses reports/payloads which has write access configured in foundry.toml
    string private constant DEFAULT_OUTPUT_DIR = "reports/payloads";

    /**
     * @dev Captures PacketSent events and saves full encoded payloads
     * @param endpointV2 Address of the LayerZero EndpointV2 contract (defaults to mainnet address)
     * @param outputDir Directory to save payload files (defaults to reports/payloads)
     * @param spellId Spell identifier for file naming
     * @return filePaths Array of file paths where payloads were saved
     * @return payloads Array of full encoded payloads from PacketSent events
     */
    function capturePayloads(
        address endpointV2,
        string memory outputDir,
        string memory spellId
    ) internal returns (string[] memory filePaths, bytes[] memory payloads) {
        // Use defaults if not provided
        if (endpointV2 == address(0)) {
            endpointV2 = DEFAULT_ENDPOINT_V2;
        }
        if (bytes(outputDir).length == 0) {
            outputDir = DEFAULT_OUTPUT_DIR;
        }

        // Get all recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Filter for PacketSent events from EndpointV2
        uint256 packetCount = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == PACKET_SENT_TOPIC) {
                if (logs[i].emitter == endpointV2) {
                    packetCount++;
                }
            }
        }

        // Allocate arrays
        filePaths = new string[](packetCount);
        payloads = new bytes[](packetCount);

        // Process logs and extract payloads
        uint256 index = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == PACKET_SENT_TOPIC) {
                if (logs[i].emitter == endpointV2) {
                    // Decode event data: PacketSent(bytes encodedPayload, bytes options, address sendLibrary)
                    (bytes memory encodedPayload,,) = abi.decode(logs[i].data, (bytes, bytes, address));

                    // Store the full encoded payload (includes all LayerZero packet metadata)
                    payloads[index] = encodedPayload;

                    // Generate filename: {spell-id}-{index}.txt
                    string memory filename = string(abi.encodePacked(spellId, "-", vm.toString(index), ".txt"));

                    // Create full file path
                    string memory filePath = string(abi.encodePacked(outputDir, "/", filename));

                    // Convert payload to hex string (without 0x prefix)
                    string memory hexPayload = _bytesToHex(encodedPayload);

                    // Create directory if it doesn't exist (Foundry allows this)
                    // Note: Users may need to run tests with --fs flag for file system access
                    try vm.createDir(outputDir, true) {} catch {}

                    // Write to file
                    vm.writeFile(filePath, hexPayload);

                    filePaths[index] = filePath;
                    index++;

                    console.log("Captured payload index:", index - 1);
                    console.log("File path:", filePath);
                    console.log("Payload size:", encodedPayload.length);
                }
            }
        }

        console.log("Total payloads captured:", packetCount);
    }

    /**
     * @dev Converts bytes to hex string without 0x prefix
     * @param data Bytes to convert
     * @return hexString Hex string representation
     */
    function _bytesToHex(bytes memory data) private pure returns (string memory hexString) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(data.length * 2);

        for (uint256 i = 0; i < data.length; i++) {
            result[i * 2] = hexChars[uint8(data[i] >> 4)];
            result[i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }

        return string(result);
    }

    /**
     * @dev Starts recording logs for PacketSent event capture
     * @notice Should be called before executeAllPayloadsAndBridges()
     */
    function startCapture() internal {
        vm.recordLogs();
    }

    /**
     * @dev Gets the default EndpointV2 address
     * @return Default EndpointV2 address
     */
    function getDefaultEndpointV2() internal pure returns (address) {
        return DEFAULT_ENDPOINT_V2;
    }
}
