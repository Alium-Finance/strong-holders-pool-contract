/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./IStrongHolder.sol";

contract StrongHolderPool is IStrongHolder, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    Counters.Counter private _poolIndex;

    address public rewardToken;
    address public trusted;

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

    // pool id -> data
    mapping (uint256 => Pool) public pools;

    constructor(address _aliumToken) {
        rewardToken = _aliumToken;
    }

    function lock(address _to, uint256 _amount) external override {
        IERC20(rewardToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        _lock(_to, _amount);
    }

    // used only for trusted caller,
    // before call this function, tokens amount MUST be transferred to contract
    function trustedLock(address _to, uint256 _amount) external override onlyTrusted {
        _lock(_to, _amount);
    }

    function withdraw(uint256 _poolId) external override {
        require(
            _poolId < Counters.current(_poolIndex),
            "Only whole pool"
        );

        Pool storage pool = pools[_poolId];

        require(
            pool.leftTracker < 100,
            "Pool is empty"
        );

        uint position = uint256(100).sub(pool.leftTracker);

        uint l = 100;
        for (uint i; i < l; i++) {
            if (pool.users[i].account == msg.sender) {
                pool.users[i].paid = true;
                pool.position[position] = i;
                pool.leftTracker++;
                _countAndWithdraw(i, position, pool.users[i].account, pool.users[i].balance);
            }
        }
    }

    function percentFrom(uint _percent, uint _value) public pure returns (uint256 result) {
        result = _percent * _value / 100;
    }

    function getPoolWithdrawPosition(uint256 _poolId)
        external
        view
        override
        returns (uint256 position)
    {
        require(
            _poolId < Counters.current(_poolIndex),
            "Only whole pool"
        );

        Pool storage pool = pools[_poolId];

        require(
            pool.leftTracker < 100,
            "Pool is empty"
        );

        return uint256(100).sub(pool.leftTracker);
    }

    function totalLockedPoolTokens(uint256 _poolId) public view returns (uint256 amount) {
        Pool storage pool = pools[_poolId];
        uint l = pool.users.length;
        for (uint i; i < l; i++) {
            amount += pool.users[i].balance;
        }
    }

    function totalLockedPoolTokensFrom(uint256 _poolId, uint _position) public view returns (uint256 amount) {
        Pool storage pool = pools[_poolId];
        uint l = pool.users.length;
        for (uint i = 0; i < l; i++) {
            if (!pool.users[i].paid && pool.users[i].leftId >= _position) {
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
        }
        IERC20(rewardToken).transfer(_account, amount);
    }

    function _lock(address _to, uint256 _amount) internal {
        uint256 _poolId = Counters.current(_poolIndex);
        if (pools[_poolId].users.length == 100) {
            Counters.increment(_poolIndex);
            _poolId = Counters.current(_poolIndex);
        }

        Pool storage pool = pools[_poolId];

        uint l = pool.users.length;
        for (uint i; i < l; i++) {
            if (
                pool.users[i].account != _to &&
                l - 1 == i
            ) {
                pool.users.push(User({
                account: _to,
                balance: _amount,
                paid: false,
                leftId: 0
                }));
            } else if (pool.users[i].account == _to) {
                pool.users[i].balance += _amount;
                return;
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

    function _countBonuses(uint _poolId, uint _position, uint _balance) internal view returns (uint bonus) {
        if (_position <= 100-80 && _position > 100-85) {
            // 80-85
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 80);
            bonus = _balance / totalTokensBonus * percentFrom(20, pools[_poolId].withheldFunds);
        } else if (_position <= 100-85 && _position > 100-90) {
            // 85-90
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 85);
            bonus = _balance / totalTokensBonus * percentFrom(
                40,
                pools[_poolId].withheldFunds - pools[_poolId].bonusesPaid[0]
            );
        } else if (_position <= 100-90 && _position > 100-95) {
            // 90-95
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 90);
            bonus = _balance / totalTokensBonus * percentFrom(
                60,
                pools[_poolId].withheldFunds - pools[_poolId].bonusesPaid[0] -
                pools[_poolId].bonusesPaid[1]
            );
        } else if (_position <= 100-95 && _position > 100-100) {
            // 100
            if (_position == 100-100) {
                return bonus = pools[_poolId].withheldFunds - pools[_poolId].bonusesPaid[0] -
                pools[_poolId].bonusesPaid[1] - pools[_poolId].bonusesPaid[2] -
                pools[_poolId].bonusesPaid[3];
            }
            // 95-100
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 95);
            bonus = _balance / totalTokensBonus * (
            pools[_poolId].withheldFunds - pools[_poolId].bonusesPaid[0] -
            pools[_poolId].bonusesPaid[1] - pools[_poolId].bonusesPaid[2]
            );
        }

    }

    function _countReward(uint _poolId, uint _position, uint _balance) internal view returns (uint256 reward) {
        uint totalTokens = totalLockedPoolTokens(_poolId);

        //70%
        if (_position <= 100 && _position > 100-35) {
            if (70 * totalTokens >= 70 * (totalTokens - _balance)) {
                return _balance - (70 * (totalTokens - _balance));
            } else {
                return _balance - (70 * totalTokens);
            }
        }
        //50%
        if (_position <= 100-35 && _position > 100-55) {
            if (50 * totalTokens >= 50 * (totalTokens - _balance)) {
                return _balance - (50 * (totalTokens - _balance));
            } else {
                return _balance - (50 * totalTokens);
            }
        }
        //25%
        if (_position <= 100-55 && _position > 100-70) {
            if (25 * totalTokens >= 25 * (totalTokens - _balance)) {
                return _balance - (25 * (totalTokens - _balance));
            } else {
                return _balance - (25 * totalTokens);
            }
        }
        // 0%
        if (_position <= 100-70 && _position > 100-80) {
            return _balance;
        }
        if (_position <= 100-80) {
            // 80-100
            return _balance;
        }
    }

    function setTrustedContract(address _trusted) external onlyOwner {
        trusted = _trusted;
    }

    modifier onlyTrusted() {
        require(
            msg.sender == trusted,
            "only trusted caller"
        );
        _;
    }

}