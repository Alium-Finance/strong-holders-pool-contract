/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./IStrongHolder.sol";

contract StrongHolderPool is IStrongHolder, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct User {
        address account;
        uint256 balance;
        bool paid;
        uint256 leftId;
    }

    struct Pool {
        User[] users;
        uint256 leftTracker;
        uint256 withheldFunds;
        uint256[4] bonusesPaid;
        mapping (uint => uint) position;
    }

    address public rewardToken;

    uint public constant MAX_POOL_LENGTH = 100;

    Counters.Counter private _poolIndex;

    // pool id -> data
    mapping (uint256 => Pool) public pools;

    event Bonus(address, uint);
    event Withdrawn(address account, uint256 amount);
    event Withheld(uint amount);

    constructor(address _aliumToken) {
        require(_aliumToken != address(0), "Reward token set zero address");

        rewardToken = _aliumToken;
    }

    function lock(address _to, uint256 _amount) external virtual override nonReentrant {
        require(_to != address(0), "Lock for zero address");
        require(_amount >= 100_000, "Not enough for participate");

        IERC20(rewardToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        _lock(_to, _amount);
    }

    function withdraw(uint256 _poolId) external override nonReentrant {
        _withdraw(_poolId, msg.sender);
    }

    function _withdraw(uint256 _poolId, address _to) internal {
        require(
            poolLength(_poolId) == 100,
            "Only whole pool"
        );

        Pool storage pool = pools[_poolId];

        require(
            pool.leftTracker <= 100,
            "Pool is empty"
        );

        uint position = uint256(100).sub(pool.leftTracker);

        uint l = 100;
        for (uint i; i < l; i++) {
            if (pool.users[i].account == _to) {
                pool.users[i].paid = true;
                pool.position[position] = i;
                pool.leftTracker++;
                _countAndWithdraw(_poolId, position, pool.users[i].account, pool.users[i].balance);
                return;
            }
        }

        revert("User not found");
    }

    function percentFrom(uint _percent, uint _num) public pure returns (uint256 result) {
        require(_percent != 0 && _percent <= 100, "percent from: wrong _percent");

        result = _num.mul(_percent).div(100);
    }

    function getPoolWithdrawPosition(uint256 _poolId)
        external
        view
        override
        returns (uint256 position)
    {
        require(
            poolLength(_poolId) == 100,
            "Only whole pool"
        );

        Pool storage pool = pools[_poolId];

        require(
            pool.leftTracker < 100,
            "Pool is empty"
        );

        return uint256(100).sub(pool.leftTracker);
    }

    function currentPoolLength() public view returns (uint256) {
        return pools[Counters.current(_poolIndex)].users.length;
    }

    function getCurrentPoolId() public view returns (uint256) {
        return Counters.current(_poolIndex);
    }

    function poolLength(uint _poolId) public view returns (uint256) {
        return pools[_poolId].users.length;
    }

    function userLockedPoolTokens(uint256 _poolId, address _account) public view returns (uint256) {
        Pool storage pool = pools[_poolId];
        uint l = pool.users.length;
        for (uint i; i < l; i++) {
            if (pool.users[i].account == _account) {
                return pool.users[i].balance;
            }
        }
    }

    function totalLockedPoolTokens(uint256 _poolId) public view returns (uint256 amount) {
        Pool storage pool = pools[_poolId];
        uint l = pool.users.length;
        for (uint i; i < l; i++) {
            amount += pool.users[i].balance;
        }
    }

    function totalLockedPoolTokensFrom(uint256 _poolId, uint _leftPosition) public view returns (uint256 amount) {
        Pool storage pool = pools[_poolId];
        if (pool.leftTracker < _leftPosition) {
            return 0;
        }

        uint l = pool.users.length;
        for (uint i = 0; i < l; i++) {
            if (pool.users[i].leftId >= _leftPosition && pool.users[i].paid) {
                amount += pool.users[i].balance;
            }
            if (!pool.users[i].paid) {
                amount += pool.users[i].balance;
            }
        }
    }

    function _countAndWithdraw(uint _poolId, uint _position, address _account, uint _balance) internal {
        uint amount = _countReward(_poolId, _position, _balance);
        uint bonus = _countBonuses(_poolId, _position, _balance);
        if (bonus > 0) {
            _payBonus(_poolId, _position, bonus);
            amount += bonus;
            emit Bonus(_account, bonus);
        }
        IERC20(rewardToken).safeTransfer(_account, amount);
        emit Withdrawn(_account, amount);
    }

    function _lock(address _to, uint256 _amount) internal {
        uint256 _poolId = Counters.current(_poolIndex);
        if (pools[_poolId].users.length == 100) {
            Counters.increment(_poolIndex);
            _poolId = Counters.current(_poolIndex);
        }

        Pool storage pool = pools[_poolId];

        uint l = pool.users.length;
        if (l == 0) {
            pool.users.push(User({
                account: _to,
                balance: _amount,
                paid: false,
                leftId: 1
            }));
        } else {
            for (uint i; i < l; i++) {
                if (
                    pool.users[i].account != _to &&
                    l - 1 == i
                ) {
                    pool.users.push(User({
                        account: _to,
                        balance: _amount,
                        paid: false,
                        leftId: l + 1
                    }));
                } else
                    if (pool.users[i].account == _to) {
                        pool.users[i].balance += _amount;
                        return;
                    }
            }
        }
    }

    function _payBonus(uint _poolId, uint256 _position, uint256 _bonus) internal {
        if (_position <= 100-80 && _position > 100-85) {
            pools[_poolId].bonusesPaid[0] += _bonus;
        } else if (_position <= 100-85 && _position > 100-90) {
            pools[_poolId].bonusesPaid[1] += _bonus;
        } else if (_position <= 100-90 && _position > 100-95) {
            pools[_poolId].bonusesPaid[2] += _bonus;
        } else if (_position <= 100-95 && _position > 100-100) {
            pools[_poolId].bonusesPaid[3] += _bonus;
        }
    }

    event Test(uint, uint);
    event Test2(uint, uint, uint);

    function poolWithheld(uint _poolId) public view returns (uint) {
        return pools[_poolId].withheldFunds;
    }

    function _countBonuses(uint _poolId, uint _position, uint _balance) internal returns (uint bonus) {
        if (_position <= 20 && _position > 15) {
            // 80-85
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 80+1);
            bonus = _balance
                .mul(percentFrom(20, pools[_poolId].withheldFunds))
                .div(totalTokensBonus, "cbon 1");
        } else
        if (_position <= 15 && _position > 10) {
            // 85-90
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 85+1);
            bonus = _balance
            .mul(percentFrom(40,
                pools[_poolId].withheldFunds.sub(
                    pools[_poolId].bonusesPaid[0],
                    "cbon sub 1"
                )
            ))
            .div(totalTokensBonus, "cbon 1");
        } else
        if (_position <= 10 && _position > 5) {
            // 90-95
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 90+1);
            bonus = _balance
            .mul(percentFrom(60,
                pools[_poolId].withheldFunds.sub(
                    pools[_poolId].bonusesPaid[0] +
                    pools[_poolId].bonusesPaid[1],
                    "cbon sub 2"
                )
            ))
            .div(totalTokensBonus, "cbon 1");
        } else
        if (_position <= 5 && _position > 0) {
            // 100
            if (_position == 1) {
                return bonus = pools[_poolId].withheldFunds.sub(
                    pools[_poolId].bonusesPaid[0] +
                    pools[_poolId].bonusesPaid[1] +
                    pools[_poolId].bonusesPaid[2] +
                    pools[_poolId].bonusesPaid[3],
                    "sub last"
                );
            }
            // 95-99
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 95+1);
            bonus = _balance
            .mul(
                pools[_poolId].withheldFunds.sub(
                    pools[_poolId].bonusesPaid[0] +
                    pools[_poolId].bonusesPaid[1] +
                    pools[_poolId].bonusesPaid[2],
                    "cbon sub 3"
                )
            )
            .div(totalTokensBonus, "cbon 1");
        }
    }

    function _findMinCountReward(uint _poolId, uint _balance, uint _percent) private returns (uint256 reward) {
        uint _totalTokens = totalLockedPoolTokens(_poolId);
        //        emit Test(_totalTokens, _balance);
//        return 1;
        uint deposited = percentFrom(_percent, _balance);
        uint poolLeft = percentFrom(_percent, _totalTokens.sub(_balance, "fmcr 1"));
        if (poolLeft < deposited) {
            reward = _balance.sub(poolLeft, "fmcr 2");
            pools[_poolId].withheldFunds += poolLeft;
            emit Withheld(poolLeft);
        } else {
            reward = _balance.sub(deposited, "fmcr 3");
            pools[_poolId].withheldFunds += deposited;
            emit Withheld(deposited);
        }
    }

    function _countReward(uint _poolId, uint _position, uint _balance) internal returns (uint256 reward) {
        //uint totalTokens = totalLockedPoolTokens(_poolId);

        //70%
        if (_position <= 100 && _position > 100-35) {
            return _findMinCountReward(_poolId, _balance, 70);
        } else
        //50%
        if (_position <= 100-35 && _position > 100-55) {
            return _findMinCountReward(_poolId, _balance, 50);
        } else
        //25%
        if (_position <= 100-55 && _position > 100-70) {
            return _findMinCountReward(_poolId, _balance, 25);
        } else
        // 0%
        if (_position <= 100-70 && _position >= 0) {
            return _balance;
        }
    }
}