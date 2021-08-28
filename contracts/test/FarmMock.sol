/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '../interfaces/IStrongHolder.sol';

contract FarmMock {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public rewardToken;
    address public shp;

    constructor(
        address _rewardToken,
        address _shp
    ) {
        rewardToken = _rewardToken;
        shp = _shp;

        IERC20(rewardToken).safeApprove(shp, type(uint256).max);
    }

    function deposit(uint256 _pid, uint256 _amount) external {
        if (_amount >= 100_000) {
//            IERC20(rewardToken).safeApprove(shp, type(uint256).max);
            IStrongHolder(shp).lock(msg.sender, _amount);
        }
    }
}