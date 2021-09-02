/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../interfaces/IAliumGaming1155.sol";
import "./AccessControlToken.sol";
import "./RoyaltyToken.sol";

contract AliumGaming1155 is
    IAliumGaming1155,
    ERC1155,
    AccessControlToken,
    RoyaltyToken
{
    constructor(string memory _tokenUrl) ERC1155(_tokenUrl) {
        //
    }

    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _tokenAmount,
        bytes memory _data
    ) external override onlyRole(MINTER_ROLE) {
        _mint(_to, _tokenId, _tokenAmount, _data);
    }

    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) external override onlyRole(MINTER_ROLE) {
        _mintBatch(_to, _ids, _amounts, _data);
    }

    function burn(uint256 _tokenId, uint256 _tokenAmount) external override {
        _burn(_msgSender(), _tokenId, _tokenAmount);
    }

    function burnBatch(uint256[] memory _ids, uint256[] memory _amounts)
        external
        override
    {
        _burnBatch(_msgSender(), _ids, _amounts);
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(RoyaltyToken, AccessControlEnumerable, ERC1155, IERC165)
        returns (bool)
    {
        return
            _interfaceId == type(IAliumGaming1155).interfaceId ||
            ERC1155.supportsInterface(_interfaceId) ||
            AccessControlEnumerable.supportsInterface(_interfaceId) ||
            RoyaltyToken.supportsInterface(_interfaceId);
    }
}
