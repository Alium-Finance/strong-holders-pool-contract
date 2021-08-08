/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

//import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../IStrongHolder.sol";
import "../StrongHolderPool.sol";

contract SHPMock is StrongHolderPool {

    constructor(address _aliumToken) StrongHolderPool(_aliumToken) {
        for (uint i = 1; i <= 100; i++) {
            _lock(address(uint160(i)), i * 100_000);
        }
    }

    function getAddress(uint256 _num) external pure returns (address) {
        return address(uint160(_num));
    }

    function trustedLock(address _to, uint256 _amount) external override(StrongHolderPool) {
        _lock(_to, _amount);
    }

    function withdrawTo(uint256 _poolId, address _to) external {
        _withdraw(_poolId, _to);
    }
}