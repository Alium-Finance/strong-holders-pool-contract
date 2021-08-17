/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

interface IStrongHolder {
    function lock(address to, uint256 amount) external;

    function withdraw(uint256 poolId) external;

    function getPoolWithdrawPosition(uint256 poolId)
        external
        view
        returns (uint256 position);
}