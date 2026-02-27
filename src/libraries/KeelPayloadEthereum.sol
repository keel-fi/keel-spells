// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Ethereum} from "lib/keel-address-registry/src/Ethereum.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {KeelLiquidityLayerHelpers} from "./KeelLiquidityLayerHelpers.sol";

import {IGovernanceOAppSender, TxParams, MessagingFee, MessagingReceipt} from "src/interfaces/Interfaces.sol";

/**
 * @dev Base smart contract for Ethereum.
 * @author Exo Tech
 */
abstract contract KeelPayloadEthereum {
    using OptionsBuilder for bytes;
    address internal constant LZ_GOV_SENDER = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;

    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;

    // Solana program addresses encoded as bytes32
    // SOLANA_SVM_CONTROLLER_PROGRAM = ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
    bytes32 internal constant SOLANA_SVM_CONTROLLER_PROGRAM =
        0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;

    function execute() external {
        _execute();
    }

    /**
     * @notice Checks if the Keel Ethereum payload is executable in the current block
     * @dev Required, useful for implementing "earliest launch date" or "office hours" strategy
     * @return result The result of the check (true = executable, false = not)
     */
    function isExecutable() external pure returns (bool result) {
        result = true;
    }

    function _execute() internal virtual;

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        KeelLiquidityLayerHelpers.onboardERC4626Vault(Ethereum.ALM_RATE_LIMITS, vault, depositMax, depositSlope);
    }

    function _setUSDSMintRateLimit(uint256 maxAmount, uint256 slope) internal {
        KeelLiquidityLayerHelpers.setUSDSMintRateLimit(Ethereum.ALM_RATE_LIMITS, maxAmount, slope);
    }

    function _setUSDSToUSDCRateLimit(uint256 maxAmount, uint256 slope) internal {
        KeelLiquidityLayerHelpers.setUSDSToUSDCRateLimit(Ethereum.ALM_RATE_LIMITS, maxAmount, slope);
    }

    function _executePayload(bytes memory dstCallData) internal {
        IGovernanceOAppSender govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        TxParams memory params = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: SOLANA_SVM_CONTROLLER_PROGRAM,
            dstCallData: dstCallData,
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(150000, 0)
        });

        MessagingFee memory fee = govSender.quoteTx(params, false);

        // ---------- [Ethereum] Freeze the ALM Controller ----------
        // Note: sendTx is payable and requires ETH to be sent with the call.
        // Since this spell runs via delegatecall, address(this).balance is the proxy's balance.
        // The proxy executing this spell must have sufficient ETH to pay the messaging fee.
        require(address(this).balance >= fee.nativeFee, "Insufficient ETH balance for messaging fee");

        (bool success, bytes memory returnData) = LZ_GOV_SENDER.call{value: fee.nativeFee}(
            abi.encodeCall(IGovernanceOAppSender.sendTx, (params, fee, address(this)))
        );
        require(success, "sendTx failed");

        abi.decode(returnData, (MessagingReceipt));
    }
}
