/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

interface INFTRewardPool {
    function log(address _caller, uint256 _withdrawPosition) external;
}
