// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {
    Ethereum,
    KeelPayloadEthereum
} from "src/libraries/KeelPayloadEthereum.sol";

import {
    MainnetController
} from "lib/keel-alm-controller/src/MainnetController.sol";

import {
    IGovernanceOAppSender,
    TxParams,
    MessagingFee,
    MessagingReceipt
} from "src/interfaces/Interfaces.sol";

import {
    OptionsBuilder
} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title  Emergency Keel Ethereum Proposal
 * @notice TODO
 * @author Matariki Labs
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_unfreeze is KeelPayloadEthereum {
    using OptionsBuilder for bytes;
    address internal constant LZ_GOV_SENDER =
        0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;

    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;

    // Solana program addresses encoded as bytes32
    // SOLANA_SVM_CONTROLLER_PROGRAM = ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
    bytes32 internal constant SOLANA_SVM_CONTROLLER_PROGRAM =
        0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;

    function _execute() internal override {
        // [Ethereum] Keel - Remove relayer 1 from the ALM Controller
        _unfreezeController();
    }

    function _unfreezeController() internal {
        IGovernanceOAppSender govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        TxParams memory params = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: SOLANA_SVM_CONTROLLER_PROGRAM,
            dstCallData: bytes(
                "0005cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660001cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c11200008aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da362400000201"
            ),
            extraOptions: OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(150000, 0)
        });

        MessagingFee memory fee = govSender.quoteTx(params, false);

        // ---------- [Ethereum] Add a new relayer to the ALM Controller ----------
        // Note: sendTx is payable and requires ETH to be sent with the call.
        // Since this spell runs via delegatecall, address(this).balance is the proxy's balance.
        // The proxy executing this spell must have sufficient ETH to pay the messaging fee.
        require(
            address(this).balance >= fee.nativeFee,
            "Insufficient ETH balance for messaging fee"
        );

        (bool success, bytes memory returnData) = LZ_GOV_SENDER.call{
            value: fee.nativeFee
        }(
            abi.encodeCall(
                IGovernanceOAppSender.sendTx,
                (params, fee, LZ_GOV_SENDER)
            )
        );
        require(success, "sendTx failed");

        MessagingReceipt memory receipt = abi.decode(
            returnData,
            (MessagingReceipt)
        );
    }
}
