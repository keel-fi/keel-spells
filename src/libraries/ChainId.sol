// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.23;

import {Domain} from "xchain-helpers/testing/Domain.sol";

type ChainId is uint256;

using ChainIdUtils for ChainId global;

using { equals as == } for ChainId global;
using { notEquals as != } for ChainId global;

function equals(ChainId left, ChainId right) pure returns(bool) {
    return ChainId.unwrap(left) == ChainId.unwrap(right);
}

function notEquals(ChainId left, ChainId right) pure returns(bool) {
    return ChainId.unwrap(left) != ChainId.unwrap(right);
}

library ChainIdUtils {
    function fromDomain(Domain memory domain) internal pure returns (ChainId) {
        uint256 id = domain.chain.chainId;
        return fromUint(id);
    }

    function fromUint(uint256 id) internal pure returns (ChainId chainId) {
        if (id == 1) return ChainId.wrap(id);
        require(false, "ChainIdUtils/invalid-chain-id");
    }

    function Ethereum() internal pure returns (ChainId) {
        return ChainId.wrap(1);
    }

    function toDomainString(ChainId id) internal pure returns (string memory domainString) {
        if (ChainId.unwrap(id) == 1) return "Ethereum";
        require(false, "ChainIdUtils/invalid-chain-id");
    }
}
