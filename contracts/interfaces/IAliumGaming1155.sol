/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IAliumGaming1155 is IERC1155 {
    function mint(
        address to,
        uint256 tokenId,
        uint256 tokenAmount,
        bytes memory data
    ) external;

    function burn(
        uint256 tokenId,
        uint256 tokenAmount
    ) external;

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function burnBatch(
        uint256[] memory ids,
        uint256[] memory amounts
    ) external;
}
