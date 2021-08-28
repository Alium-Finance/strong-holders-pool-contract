// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;
pragma abicoder v2;

import "./LibPart.sol";

interface IRoyaltiesProvider {
    function getRoyalties(address token, uint tokenId) external returns (LibPart.Part[] memory);
}
