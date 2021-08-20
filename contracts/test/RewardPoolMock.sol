/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "../NFTRewardPool.sol";

contract RewardPoolMock is NFTRewardPool {
    function addBalance(address _account, uint _position, uint _amount) external {
        _balances[_account][_position] += _amount;
    }
}