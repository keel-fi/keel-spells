// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import {Ethereum, KeelPayloadEthereum} from "src/libraries/KeelPayloadEthereum.sol";

import {MainnetController} from "lib/keel-alm-controller/src/MainnetController.sol";

import {IGovernanceOAppSender, TxParams, MessagingFee, MessagingReceipt} from "src/interfaces/Interfaces.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title  February 12, 2026 Keel Ethereum Proposal
 * @notice TODO
 * @author Matariki Labs
 * Forum: TODO
 * Vote:  TODO
 */
contract KeelEthereum_20260212 is KeelPayloadEthereum {
    using OptionsBuilder for bytes;
    address internal constant LZ_GOV_SENDER = 0x27FC1DD771817b53bE48Dc28789533BEa53C9CCA;

    uint32 internal constant ENDPOINT_ID_SOLANA = 30168;

    // Solana program addresses encoded as bytes32
    // SOLANA_SVM_CONTROLLER_PROGRAM = ALM1JSnEhc5PkNecbSZotgprBuJujL5objTbwGtpTgTd
    bytes32 internal constant SOLANA_SVM_CONTROLLER_PROGRAM =
        0x8aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da3624;

    function _execute() internal override {
        // [Ethereum] Keel - Add a new relayer to the ALM Controller
        // Forum: TODO
        _removeRelayer1();
    }

    function _removeRelayer1() internal {
        IGovernanceOAppSender govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        TxParams memory params = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: SOLANA_SVM_CONTROLLER_PROGRAM,
            dstCallData: bytes(
                "000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c112000078fd7391b7966766a002192e93434fa5228ea92002cac08735c9bbbd77d4b657000014257c39e6858957ccfe3b6a1ae06ebe19906d4e1d64fd3c2b9f736cdf0da05300018aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da36240000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000"
            ),
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(150000, 0)
        });

        MessagingFee memory fee = govSender.quoteTx(params, false);

        // ---------- [Ethereum] Add a new relayer to the ALM Controller ----------
        // Note: sendTx is payable and requires ETH to be sent with the call.
        // Since this spell runs via delegatecall, address(this).balance is the proxy's balance.
        // The proxy executing this spell must have sufficient ETH to pay the messaging fee.
        require(address(this).balance >= fee.nativeFee, "Insufficient ETH balance for messaging fee");

        (bool success, bytes memory returnData) = LZ_GOV_SENDER.call{value: fee.nativeFee}(
            abi.encodeCall(IGovernanceOAppSender.sendTx, (params, fee, LZ_GOV_SENDER))
        );
        require(success, "sendTx failed");

        MessagingReceipt memory receipt = abi.decode(returnData, (MessagingReceipt));
    }

    function _removeRelayer2() internal {
        IGovernanceOAppSender govSender = IGovernanceOAppSender(LZ_GOV_SENDER);

        TxParams memory params = TxParams({
            dstEid: ENDPOINT_ID_SOLANA,
            dstTarget: SOLANA_SVM_CONTROLLER_PROGRAM,
            dstCallData: bytes(
                "000970617965720000000000000000000000000000000000000000000000000000000101cad71b309e306d79a1dd577e2c67f2ed713fa65ae6d4c6e86534bc303f6281660000cac3764c231540dd2364f24c78fe8f491c08c42ef2ed370f22904eda9ac486090000d327682cf394e2e8637e684a66b2dab92706e64b9490b7e438f87c5cd6e28f4b0100ece79d10f039ba13a2d4332d6cf5ae39e7ab46037886565799d6121ef180c112000018e71b744366adbd98ea4eba4ba85a516a5fbdc716c0b17c101ec192216472a60000511ceede7ec56d6bdef7dadc773c187534f892bac8ac4147117f2634e8eb451a00018aadd66fe8f142fb55a08e900228f5488fcc7d73938bbce28e313e1b87da36240000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000"
            ),
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(150000, 0)
        });

        MessagingFee memory fee = govSender.quoteTx(params, false);

        // ---------- [Ethereum] Add a new relayer to the ALM Controller ----------
        // Note: sendTx is payable and requires ETH to be sent with the call.
        // Since this spell runs via delegatecall, address(this).balance is the proxy's balance.
        // The proxy executing this spell must have sufficient ETH to pay the messaging fee.
        require(address(this).balance >= fee.nativeFee, "Insufficient ETH balance for messaging fee");

        (bool success, bytes memory returnData) = LZ_GOV_SENDER.call{value: fee.nativeFee}(
            abi.encodeCall(IGovernanceOAppSender.sendTx, (params, fee, LZ_GOV_SENDER))
        );
        require(success, "sendTx failed");

        MessagingReceipt memory receipt = abi.decode(returnData, (MessagingReceipt));
    }
}
