/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "../packages/@rarible/royalties/contracts/impl/RoyaltiesV1Impl.sol";
import "../packages/@rarible/royalties/contracts/LibRoyaltiesV1.sol";
import "../packages/@rarible/royalties/contracts/IRoyaltiesProvider.sol";
import { AccessControlEnumerable, AccessControlToken } from "./AccessControlToken.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

contract RoyaltyToken is RoyaltiesV1Impl, AccessControlToken, ERC165Storage, IRoyaltiesProvider {

    constructor() {
        _registerInterface(LibRoyaltiesV1._INTERFACE_ID_FEES);
        _registerInterface(type(IRoyaltiesProvider).interfaceId);
    }

    function saveRoyalties(uint256 _tokenId, LibPart.Part[] memory _royalties) external onlyRole(ADMIN_ROLE) {
        _saveRoyalties(_tokenId, _royalties);
    }

    function updateAccount(uint256 _tokenId, address _from, address _to) external onlyRole(ADMIN_ROLE) {
        _updateAccount(_tokenId, _from, _to);
    }

    function getRoyalties(address token, uint tokenId) external override returns (LibPart.Part[] memory) {
        return royalties[tokenId];
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override(AccessControlEnumerable, ERC165Storage) returns (bool) {
        return AccessControlEnumerable.supportsInterface(_interfaceId) ||
            ERC165Storage.supportsInterface(_interfaceId);
    }
}