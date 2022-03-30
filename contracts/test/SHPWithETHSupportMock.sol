/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "../interfaces/IStrongHolder.sol";
import "../StrongETHHolderPool.sol";

contract SHPWithETHSupportMock is StrongETHHolderPool {
    struct LockBatchInput {
        address account;
        uint256 amount;
    }

    receive() external payable {}

    function fastLock() external payable {
        for (uint i = 1; i <= 100; i++) {
            _lock(address(uint160(i)), 100_000);
        }
    }

    function lockTo(address _to) external payable {
        for (uint i = 1; i <= 100; i++) {
            _lock(_to, msg.value);
        }
    }

    function lockBatch(LockBatchInput[] memory _input) external payable {
        for (uint i = 0; i < _input.length; i++) {
            _lock(_input[i].account, _input[i].amount);
        }
    }

    function getAddress(uint256 _num) public pure returns (address) {
        return address(uint160(_num));
    }

    function withdrawTo(uint256 _poolId, address _to) external {
        _withdraw(_poolId, _to);
    }
}