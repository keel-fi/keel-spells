#!/usr/bin/env ts-node

/**
 * Script to extract LayerZero payloads from Forge test traces/logs
 * 
 * This is a fallback utility that can extract payloads from Forge test output
 * if the Solidity capture doesn't work in all scenarios.
 * 
 * Usage:
 *   forge test --json | ts-node script/extract-forge-payload.ts [output-dir]
 * 
 * Or with a test file:
 *   forge test --json test/MyTest.t.sol | ts-node script/extract-forge-payload.ts
 */

import * as fs from "fs";
import * as path from "path";
import { ethers } from "ethers";

// PacketSent event signature
const PACKET_SENT_SIGNATURE = "PacketSent(bytes,bytes,address)";
const PACKET_SENT_TOPIC = ethers.id(PACKET_SENT_SIGNATURE);

// PacketV1Codec message extraction (simplified - would need full implementation)
// For now, this script serves as a placeholder for future enhancement

interface ForgeTestResult {
    type: string;
    name?: string;
    traces?: any[];
    logs?: any[];
}

/**
 * Extract payloads from Forge test JSON output
 */
function extractPayloadsFromForgeOutput(input: string, outputDir: string = "test-output/payloads"): void {
    try {
        const data = JSON.parse(input);
        
        if (!Array.isArray(data)) {
            console.error("Expected array of test results");
            process.exit(1);
        }

        let payloadCount = 0;

        for (const result of data) {
            if (result.type === "test" && result.traces) {
                // Process traces to find PacketSent events
                const payloads = findPacketSentEvents(result.traces);
                
                for (let i = 0; i < payloads.length; i++) {
                    const payload = payloads[i];
                    const filename = `forge-${payloadCount++}.txt`;
                    const filePath = path.join(outputDir, filename);
                    
                    // Ensure output directory exists
                    if (!fs.existsSync(outputDir)) {
                        fs.mkdirSync(outputDir, { recursive: true });
                    }
                    
                    // Write payload (hex without 0x prefix)
                    const hexPayload = payload.startsWith("0x") 
                        ? payload.slice(2) 
                        : payload;
                    
                    fs.writeFileSync(filePath, hexPayload, "utf-8");
                    console.log(`Extracted payload to: ${filePath}`);
                }
            }
        }

        if (payloadCount === 0) {
            console.warn("No PacketSent events found in test output");
        } else {
            console.log(`\n✅ Extracted ${payloadCount} payload(s) to ${outputDir}`);
        }
    } catch (error) {
        console.error("Error parsing Forge output:", error);
        process.exit(1);
    }
}

/**
 * Recursively search traces for PacketSent events
 */
function findPacketSentEvents(traces: any[]): string[] {
    const payloads: string[] = [];
    
    function searchTrace(trace: any): void {
        // Check if this trace has logs
        if (trace.logs && Array.isArray(trace.logs)) {
            for (const log of trace.logs) {
                // Check if log matches PacketSent event
                if (log.topics && log.topics[0] === PACKET_SENT_TOPIC) {
                    // Decode event data
                    try {
                        const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
                            ["bytes", "bytes", "address"],
                            log.data
                        );
                        const encodedPayload = decoded[0];
                        
                        // Extract message from encoded payload
                        // Note: This is a simplified version - full implementation would
                        // need to decode the PacketV1Codec format
                        // For now, we'll extract what we can
                        const message = extractMessageFromPacket(encodedPayload);
                        if (message) {
                            payloads.push(message);
                        }
                    } catch (error) {
                        console.warn("Failed to decode PacketSent event:", error);
                    }
                }
            }
        }
        
        // Recursively search nested traces
        if (trace.calls && Array.isArray(trace.calls)) {
            for (const call of trace.calls) {
                searchTrace(call);
            }
        }
    }
    
    for (const trace of traces) {
        searchTrace(trace);
    }
    
    return payloads;
}

/**
 * Extract message from encoded packet
 * This is a simplified version - full implementation would properly decode PacketV1Codec
 */
function extractMessageFromPacket(encodedPacket: string): string | null {
    try {
        // This is a placeholder - actual implementation would need to:
        // 1. Decode the PacketV1Codec format
        // 2. Extract the message field from the packet
        // 3. Return the message as hex string
        
        // For now, return null to indicate this needs full implementation
        console.warn("Message extraction from packet not fully implemented");
        return null;
    } catch (error) {
        console.warn("Failed to extract message from packet:", error);
        return null;
    }
}

/**
 * Main function
 */
function main() {
    const args = process.argv.slice(2);
    const outputDir = args[0] || "test-output/payloads";
    
    // Read from stdin
    let input = "";
    process.stdin.setEncoding("utf8");
    
    process.stdin.on("data", (chunk) => {
        input += chunk;
    });
    
    process.stdin.on("end", () => {
        if (!input.trim()) {
            console.error("No input received. Pipe Forge test output to this script:");
            console.error("  forge test --json | ts-node script/extract-forge-payload.ts");
            process.exit(1);
        }
        
        extractPayloadsFromForgeOutput(input, outputDir);
    });
}

if (require.main === module) {
    main();
}
