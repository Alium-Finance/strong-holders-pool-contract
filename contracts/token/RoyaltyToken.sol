/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "../packages/@rarible/royalties/contracts/impl/RoyaltiesV1Impl.sol";
import "../packages/@rarible/royalties/contracts/LibRoyaltiesV1.sol";
import {AccessControlEnumerable, AccessControlToken} from "./AccessControlToken.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

contract RoyaltyToken is RoyaltiesV1Impl, AccessControlToken, ERC165Storage {
    struct RoyaltiesBatch {
        uint256 tokenId;
        LibPart.Part[] royalties;
    }

    uint256 public constant ROYALTY_DECIMAL = 10_000;

    constructor() {
        _registerInterface(LibRoyaltiesV1._INTERFACE_ID_FEES);
    }

    function saveRoyalties(uint256 _tokenId, LibPart.Part[] memory _royalties)
        external
        onlyRole(ADMIN_ROLE)
    {
        _saveRoyalties(_tokenId, _royalties);
    }

    function saveRoyaltiesBatch(RoyaltiesBatch[] memory _batch)
        external
        onlyRole(ADMIN_ROLE)
    {
        uint256 l = _batch.length;
        for (uint256 i; i < l; i++) {
            _saveRoyalties(_batch[i].tokenId, _batch[i].royalties);
        }
    }

    function updateAccount(
        uint256 _tokenId,
        address _from,
        address _to
    ) external onlyRole(ADMIN_ROLE) {
        _updateAccount(_tokenId, _from, _to);
    }

    function getRoyalties(uint256 _tokenId)
        external
        view
        returns (LibPart.Part[] memory)
    {
        return _royalties[_tokenId];
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC165Storage)
        returns (bool)
    {
        return
            AccessControlEnumerable.supportsInterface(_interfaceId) ||
            ERC165Storage.supportsInterface(_interfaceId);
    }
}
