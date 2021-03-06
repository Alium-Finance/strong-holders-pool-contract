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
        uint256 withdrawn;
        uint256[4] bonusesPaid;
        mapping(uint256 => uint256) position;
    }

    address public rewardToken;
    address public nftRewardPool;

    uint256 public constant MAX_POOL_LENGTH = 100;
    uint256 public minDeposit;

    Counters.Counter private _poolIndex;

    // pool id -> data
    mapping(uint256 => Pool) public pools;

    event Bonus(address, uint256);
    event Deposited(uint256 indexed poolId, address account, uint256 amount);
    event Withdrawn(uint256 indexed poolId, uint256 position, address account, uint256 amount);
    event Withheld(uint256 amount);
    event RewardPoolSet(address rewardPool);
    event MinDepositSet(uint256 value);
    event PoolCreated(uint256 poolId);

    /**
     * @dev Constructor. Set `_aliumToken` as reward token.
     */
    constructor(address _aliumToken) {
        require(_aliumToken != address(0), "Reward token set zero address");

        rewardToken = _aliumToken;
        minDeposit = 100_000;
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
        require(_amount >= minDeposit, "Not enough for participate");

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
        returns (uint256 balance)
    {
        Pool storage pool = pools[_poolId];
        uint256 l = pool.users.length;
        for (uint256 i; i < l; i++) {
            if (pool.users[i].account == _account) {
                balance = pool.users[i].balance;
                i = l;
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
     * @dev Returns current withdraw position reward for `_account` by `_poolId`.
     */
    function countReward(uint256 _poolId, address _account)
        external
        view
        returns (uint256 reward)
    {
        Pool storage pool = pools[_poolId];

        for (uint256 i; i < 100; i++) {
            if (pool.users[i].account == _account) {
                if (pool.users[i].paid) {
                    return reward;
                }

                uint256 position = uint256(100).sub(pool.leftTracker);
                uint256 withheld;
                (reward, withheld) = _countReward(_poolId, position, pool.users[i].balance);

                uint256 bonus = _countBonuses(_poolId, position, pool.users[i].balance, pool.withheldFunds);
                if (bonus > 0) {
                    reward += bonus;
                }

                return reward;
            }
        }
    }

    /**
     * @dev Set NFT reward pool.
     */
    function setNftRewardPool(address _rewardPool) external onlyOwner {
        nftRewardPool = _rewardPool;
        emit RewardPoolSet(_rewardPool);
    }

    /**
     * @dev Set NFT reward pool.
     */
    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        require(_minDeposit >= 100_000, "Very low deposit");

        minDeposit = _minDeposit;
        emit MinDepositSet(_minDeposit);
    }

    /**
     * @dev Get pool length by `_poolId`.
     */
    function poolLength(uint256 _poolId) public view returns (uint256) {
        return pools[_poolId].users.length;
    }

    /**
     * @dev Get users list by `_poolId`.
     */
    function users(uint256 _poolId) external view returns (User[] memory _users) {
        _users = pools[_poolId].users;
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
     *      _leftPosition - [1...100]
     */
    function totalLockedPoolTokensFrom(uint256 _poolId, uint256 _leftPosition)
        public
        view
        returns (uint256 amount)
    {
        Pool storage pool = pools[_poolId];

        uint256 poolBalance;
        uint256 withdrawnBalance;
        uint256 l = pool.users.length;
        for (uint256 i; i < l; i++) {
            poolBalance += pool.users[i].balance;

            if (
                pool.users[i].leftId != 0 &&
                pool.users[i].leftId < _leftPosition
            ) {
                withdrawnBalance += pool.users[i].balance;
            }
        }

        amount = poolBalance - withdrawnBalance;
    }

    function _countAndWithdraw(
        uint256 _poolId,
        uint256 _position,
        address _account,
        uint256 _balance
    ) internal {
        (uint256 amount, uint256 withheld) = _countReward(_poolId, _position, _balance);
        uint256 bonus = _countBonuses(
            _poolId,
            _position,
            _balance,
            pools[_poolId].withheldFunds
        );
        if (withheld > 0) {
            pools[_poolId].withheldFunds += withheld;
            emit Withheld(withheld);
        }
        if (bonus > 0) {
            _payBonus(_poolId, _position, bonus);
            amount += bonus;
            emit Bonus(_account, bonus);
        }
        IERC20(rewardToken).safeTransfer(_account, amount);
        if (nftRewardPool != address(0)) {
            INFTRewardPool(nftRewardPool).log(_account, _position);
        }
        pools[_poolId].withdrawn += amount;
        emit Withdrawn(_poolId, _position, _account, amount);
    }

    function _lock(address _to, uint256 _amount) internal {
        uint256 _poolId = Counters.current(_poolIndex);

        Pool storage pool = pools[_poolId];

        uint256 l = pool.users.length;
        if (l == 0) {
            pool.users.push(
                User({account: _to, balance: _amount, paid: false, leftId: 0})
            );
            emit PoolCreated(_poolId);
        } else {
            for (uint256 i; i < l; i++) {
                if (pool.users[i].account != _to && l - 1 == i) {
                    pool.users.push(
                        User({
                            account: _to,
                            balance: _amount,
                            paid: false,
                            leftId: 0
                        })
                    );

                    if (pools[_poolId].users.length == 100) {
                        Counters.increment(_poolIndex);
                    }
                } else if (pool.users[i].account == _to) {
                    pool.users[i].balance += _amount;
                    return;
                }
            }
        }
        emit Deposited(_poolId, _to, _amount);
    }

    function _payBonus(
        uint256 _poolId,
        uint256 _position,
        uint256 _bonus
    ) internal {
        if (_position <= 20 && _position > 15) {
            pools[_poolId].bonusesPaid[0] += _bonus;
        } else if (_position <= 15 && _position > 10) {
            pools[_poolId].bonusesPaid[1] += _bonus;
        } else if (_position <= 10 && _position > 5) {
            pools[_poolId].bonusesPaid[2] += _bonus;
        } else if (_position <= 5 && _position > 0) {
            pools[_poolId].bonusesPaid[3] += _bonus;
        }
    }

    function _countBonuses(
        uint256 _poolId,
        uint256 _position,
        uint256 _balance,
        uint256 _withheld
    ) internal view returns (uint256 bonus) {
        uint256 totalTokensBonus;
        if (_position <= 20 && _position > 15) {
            // 81-85
            totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 81);
            bonus = _balance
                .mul(percentFrom(20, _withheld))
                .div(totalTokensBonus, "Total tokens bonus div");
        } else if (_position <= 15 && _position > 10) {
            // 86-90
            totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 86);
            bonus = _balance
                .mul(
                    percentFrom(
                        40,
                        _withheld.sub(
                            pools[_poolId].bonusesPaid[0]
                        )
                    )
                )
                .div(totalTokensBonus);
        } else if (_position <= 10 && _position > 5) {
            // 91-95
            totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 91);
            bonus = _balance
                .mul(
                    percentFrom(
                        60,
                        _withheld.sub(
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
                    bonus = _withheld.sub(
                        pools[_poolId].bonusesPaid[0] +
                            pools[_poolId].bonusesPaid[1] +
                            pools[_poolId].bonusesPaid[2] +
                            pools[_poolId].bonusesPaid[3]
                    );
            }
            // 96-99
            totalTokensBonus = totalLockedPoolTokensFrom(_poolId, 96);
            bonus = _balance
                .mul(
                    _withheld.sub(
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
    ) private view returns (uint256 reward, uint256 withheld) {
        uint256 _totalTokens = totalLockedPoolTokens(_poolId);
        uint256 deposited = percentFrom(_percent, _balance);
        uint256 poolLeft = percentFrom(_percent, _totalTokens.sub(_balance));
        if (poolLeft < deposited) {
            reward = _balance.sub(poolLeft);
            withheld = poolLeft;
        } else {
            reward = _balance.sub(deposited);
            withheld = deposited;
        }
    }

    function _countReward(
        uint256 _poolId,
        uint256 _position,
        uint256 _balance
    ) internal view returns (uint256 reward, uint256 withheld) {
        // k-70% (100 - 100-35)
        if (_position <= 100 && _position > 65) {
            (reward, withheld) = _findMinCountReward(_poolId, _balance, 70);
        }
        // k-50% (100-35 - 100-55)
        else if (_position <= 65 && _position > 45) {
            (reward, withheld) = _findMinCountReward(_poolId, _balance, 50);
        }
        // k-25% (100-55 - 100-70)
        else if (_position <= 45 && _position > 30) {
            (reward, withheld) = _findMinCountReward(_poolId, _balance, 25);
        }
        // k-0% (100-70 - 0)
        else if (_position <= 30) {
            reward = _balance;
        }
    }

    function _withdraw(uint256 _poolId, address _to) internal {
        require(poolLength(_poolId) == 100, "Only whole pool");

        Pool storage pool = pools[_poolId];

        require(pool.leftTracker <= 100, "Pool is empty");

        uint256 position = uint256(100).sub(pool.leftTracker);

        uint256 l = 100;
        for (uint256 i; i < l; i++) {
            if (pool.users[i].account == _to) {
                require(!pool.users[i].paid, "Reward already received");

                pool.users[i].paid = true;
                pool.position[position] = i;
                pool.leftTracker++;
                pool.users[i].leftId = pool.leftTracker;
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
}
