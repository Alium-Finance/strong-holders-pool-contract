/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IStrongHolder.sol";
import "./interfaces/INFTRewardPool.sol";

/**
 * @title StrongHolderPool - Alium token pools. Who is strongest?
 *
 *   Features:
 *
 *   - 100 places in 1 pool;
 *   - Honest redistribution;
 *   - NFT reward on side NFT pool contract.
 */
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
        mapping(uint256 => uint256) position;
    }

    address public rewardToken;
    address public nftRewardPool;

    uint256 public constant MAX_POOL_LENGTH = 100;

    Counters.Counter private _poolIndex;

    // pool id -> data
    mapping(uint256 => Pool) public pools;

    event Bonus(address, uint256);
    event Withdrawn(address account, uint256 amount);
    event Withheld(uint256 amount);

    /**
     * @dev Constructor. Set `_aliumToken` as reward token.
     */
    constructor(address _aliumToken) {
        require(_aliumToken != address(0), "Reward token set zero address");

        rewardToken = _aliumToken;
    }

    /**
     * @dev Lock `_amount` for address `_to`. It create new position or update current,
     *     if already exist.
     */
    function lock(address _to, uint256 _amount)
        external
        virtual
        override
        nonReentrant
    {
        require(_to != address(0), "Lock for zero address");
        require(_amount >= 100_000, "Not enough for participate");

        IERC20(rewardToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        _lock(_to, _amount);
    }

    /**
     * @dev Withdraw reward from contract, left position will be counted automatically.
     */
    function withdraw(uint256 _poolId) external override nonReentrant {
        _withdraw(_poolId, msg.sender);
    }

    function _withdraw(uint256 _poolId, address _to) internal {
        require(poolLength(_poolId) == 100, "Only whole pool");

        Pool storage pool = pools[_poolId];

        require(pool.leftTracker <= 100, "Pool is empty");

        uint256 position = uint256(100).sub(pool.leftTracker);

        uint256 l = 100;
        for (uint256 i; i < l; i++) {
            if (pool.users[i].account == _to) {
                pool.users[i].paid = true;
                pool.position[position] = i;
                pool.leftTracker++;
                _countAndWithdraw(
                    _poolId,
                    position,
                    pool.users[i].account,
                    pool.users[i].balance
                );
                return;
            }
        }

        revert("User not found");
    }

    /**
     * @dev Count `_percent` from `_num`.
     */
    function percentFrom(uint256 _percent, uint256 _num)
        public
        pure
        returns (uint256 result)
    {
        require(
            _percent != 0 && _percent <= 100,
            "percent from: wrong _percent"
        );

        result = _num.mul(_percent).div(100);
    }

    /**
     * @dev Get pool withdraw position for next withdraw.
     *
     * REVERT: if pool is empty or not filled.
     */
    function getPoolWithdrawPosition(uint256 _poolId)
        external
        view
        override
        returns (uint256 position)
    {
        require(poolLength(_poolId) == 100, "Only whole pool");

        Pool storage pool = pools[_poolId];

        require(pool.leftTracker < 100, "Pool is empty");

        return uint256(100).sub(pool.leftTracker);
    }

    /**
     * @dev Get current pool length.
     */
    function currentPoolLength() external view returns (uint256) {
        return pools[Counters.current(_poolIndex)].users.length;
    }

    /**
     * @dev Get current pool id.
     */
    function getCurrentPoolId() external view returns (uint256) {
        return Counters.current(_poolIndex);
    }

    /**
     * @dev Get `_account` locked tokens by `_poolId`.
     */
    function userLockedPoolTokens(uint256 _poolId, address _account)
        external
        view
        returns (uint256)
    {
        Pool storage pool = pools[_poolId];
        uint256 l = pool.users.length;
        for (uint256 i; i < l; i++) {
            if (pool.users[i].account == _account) {
                return pool.users[i].balance;
            }
        }
    }

    /**
     * @dev Returns pool withheld by `_poolId`.
     */
    function poolWithheld(uint256 _poolId) external view returns (uint256) {
        return pools[_poolId].withheldFunds;
    }

    /**
     * @dev Get total locked tokens from `_leftPosition` by `_poolId`.
     *      If left position not exist returns zero.
     */
    function setNftRewardPool(address _rewardPool) external onlyOwner {
        nftRewardPool = _rewardPool;
    }

    /**
     * @dev Get pool length by `_poolId`.
     */
    function poolLength(uint256 _poolId) public view returns (uint256) {
        return pools[_poolId].users.length;
    }

    /**
     * @dev Get total locked tokens by `_poolId`.
     */
    function totalLockedPoolTokens(uint256 _poolId)
        public
        view
        returns (uint256 amount)
    {
        Pool storage pool = pools[_poolId];
        uint256 l = pool.users.length;
        for (uint256 i; i < l; i++) {
            amount += pool.users[i].balance;
        }
    }

    /**
     * @dev Get total locked tokens from `_leftPosition` by `_poolId`.
     *      If left position not exist returns zero.
     */
    function totalLockedPoolTokensFrom(uint256 _poolId, uint256 _leftPosition)
        public
        view
        returns (uint256 amount)
    {
        Pool storage pool = pools[_poolId];
        if (pool.leftTracker < _leftPosition) {
            return 0;
        }

        uint256 l = pool.users.length;
        for (uint256 i = 0; i < l; i++) {
            if (pool.users[i].leftId >= _leftPosition && pool.users[i].paid) {
                amount += pool.users[i].balance;
            }
            if (!pool.users[i].paid) {
                amount += pool.users[i].balance;
            }
        }
    }

    function _countAndWithdraw(
        uint256 _poolId,
        uint256 _position,
        address _account,
        uint256 _balance
    ) internal {
        uint256 amount = _countReward(_poolId, _position, _balance);
        uint256 bonus = _countBonuses(_poolId, _position, _balance);
        if (bonus > 0) {
            _payBonus(_poolId, _position, bonus);
            amount += bonus;
            emit Bonus(_account, bonus);
        }
        IERC20(rewardToken).safeTransfer(_account, amount);
        if (nftRewardPool != address(0)) {
            INFTRewardPool(nftRewardPool).log(_account, _position);
        }
        emit Withdrawn(_account, amount);
    }

    function _lock(address _to, uint256 _amount) internal {
        uint256 _poolId = Counters.current(_poolIndex);
        if (pools[_poolId].users.length == 100) {
            Counters.increment(_poolIndex);
            _poolId = Counters.current(_poolIndex);
        }

        Pool storage pool = pools[_poolId];

        uint256 l = pool.users.length;
        if (l == 0) {
            pool.users.push(
                User({account: _to, balance: _amount, paid: false, leftId: 1})
            );
        } else {
            for (uint256 i; i < l; i++) {
                if (pool.users[i].account != _to && l - 1 == i) {
                    pool.users.push(
                        User({
                            account: _to,
                            balance: _amount,
                            paid: false,
                            leftId: l + 1
                        })
                    );
                } else if (pool.users[i].account == _to) {
                    pool.users[i].balance += _amount;
                    return;
                }
            }
        }
    }

    function _payBonus(
        uint256 _poolId,
        uint256 _position,
        uint256 _bonus
    ) internal {
        if (_position <= 100 - 80 && _position > 100 - 85) {
            pools[_poolId].bonusesPaid[0] += _bonus;
        } else if (_position <= 100 - 85 && _position > 100 - 90) {
            pools[_poolId].bonusesPaid[1] += _bonus;
        } else if (_position <= 100 - 90 && _position > 100 - 95) {
            pools[_poolId].bonusesPaid[2] += _bonus;
        } else if (_position <= 100 - 95 && _position > 100 - 100) {
            pools[_poolId].bonusesPaid[3] += _bonus;
        }
    }

    function _countBonuses(
        uint256 _poolId,
        uint256 _position,
        uint256 _balance
    ) internal view returns (uint256 bonus) {
        if (_position <= 20 && _position > 15) {
            // 80-85
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 81);
            bonus = _balance
                .mul(percentFrom(20, pools[_poolId].withheldFunds))
                .div(totalTokensBonus);
        } else if (_position <= 15 && _position > 10) {
            // 85-90
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 86);
            bonus = _balance
                .mul(
                    percentFrom(
                        40,
                        pools[_poolId].withheldFunds.sub(
                            pools[_poolId].bonusesPaid[0]
                        )
                    )
                )
                .div(totalTokensBonus);
        } else if (_position <= 10 && _position > 5) {
            // 90-95
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 91);
            bonus = _balance
                .mul(
                    percentFrom(
                        60,
                        pools[_poolId].withheldFunds.sub(
                            pools[_poolId].bonusesPaid[0] +
                                pools[_poolId].bonusesPaid[1]
                        )
                    )
                )
                .div(totalTokensBonus);
        } else if (_position <= 5 && _position > 0) {
            // 100
            if (_position == 1) {
                return
                    bonus = pools[_poolId].withheldFunds.sub(
                        pools[_poolId].bonusesPaid[0] +
                            pools[_poolId].bonusesPaid[1] +
                            pools[_poolId].bonusesPaid[2] +
                            pools[_poolId].bonusesPaid[3]
                    );
            }
            // 95-99
            uint256 totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 96);
            bonus = _balance
                .mul(
                    pools[_poolId].withheldFunds.sub(
                        pools[_poolId].bonusesPaid[0] +
                            pools[_poolId].bonusesPaid[1] +
                            pools[_poolId].bonusesPaid[2]
                    )
                )
                .div(totalTokensBonus);
        }
    }

    function _findMinCountReward(
        uint256 _poolId,
        uint256 _balance,
        uint256 _percent
    ) private returns (uint256 reward) {
        uint256 _totalTokens = totalLockedPoolTokens(_poolId);
        uint256 deposited = percentFrom(_percent, _balance);
        uint256 poolLeft = percentFrom(_percent, _totalTokens.sub(_balance));
        if (poolLeft < deposited) {
            reward = _balance.sub(poolLeft);
            pools[_poolId].withheldFunds += poolLeft;
            emit Withheld(poolLeft);
        } else {
            reward = _balance.sub(deposited);
            pools[_poolId].withheldFunds += deposited;
            emit Withheld(deposited);
        }
    }

    function _countReward(
        uint256 _poolId,
        uint256 _position,
        uint256 _balance
    ) internal returns (uint256) {
        // k-70% (100 - 100-35)
        if (_position <= 100 && _position > 65) {
            return _findMinCountReward(_poolId, _balance, 70);
        }
        // k-50% (100-35 - 100-55)
        else if (_position <= 65 && _position > 45) {
            return _findMinCountReward(_poolId, _balance, 50);
        }
        // k-25% (100-55 - 100-70)
        else if (_position <= 45 && _position > 30) {
            return _findMinCountReward(_poolId, _balance, 25);
        }
        // k-0% (100-70 - 0)
        else if (_position <= 30 && _position >= 0) {
            return _balance;
        }
    }
}
