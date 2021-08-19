// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
//import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../interfaces/IAliumGaming1155.sol";

contract ERC1155Mock is IAliumGaming1155, ERC1155("https://example.com/") {
    function mint(address to, uint tokenId, uint tokenAmount, bytes memory data) external override {
        _mint(to, tokenId, tokenAmount, data);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        return
        interfaceId == type(IAliumGaming1155).interfaceId ||
        super.supportsInterface(interfaceId);
    }
}
