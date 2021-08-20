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
}
