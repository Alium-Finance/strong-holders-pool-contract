/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "../interfaces/IStrongHolder.sol";
import "../StrongHolderPool.sol";

contract SHPMock is StrongHolderPool {

    struct LockBatchInput {
        address account;
        uint256 amount;
    }

    constructor(address _aliumToken) StrongHolderPool(_aliumToken) {
        //
    }

    function fastLock() external {
        for (uint i = 1; i <= 100; i++) {
            _lock(address(uint160(i)), 100_000);
        }
    }

    function lockBatch(LockBatchInput[] memory _input) external {
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