/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

interface IStrongEthereumHolder {
    function lock(address to) external payable;

    function withdraw(uint256 poolId) external;

    function getPoolWithdrawPosition(uint256 poolId)
        external
        view
        returns (uint256 position);
}
