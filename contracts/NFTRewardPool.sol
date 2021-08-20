/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/IAliumGaming1155.sol";
import "./interfaces/INFTRewardPool.sol";

/**
 * @title NFTRewardPool - Special NFT reward pool for SHP alium users and gamers.
 */
contract NFTRewardPool is INFTRewardPool, Ownable, IERC1155Receiver, ERC1155Holder {

    struct Reward {
        uint256 tokenId;
        uint256 amount;
    }

    struct InputReward {
        Reward[] rewards;
    }

    bool public status;

    IAliumGaming1155 public rewardToken;
    address public shp;

    bool public initialized;

    mapping (uint256 => Reward[]) internal _rewards;
    // pool id -> withdraw position -> counter
    mapping (address => mapping (uint256 => uint256)) internal _logs;
    // account -> tokenId -> amount
    mapping (address => mapping (uint256 => uint256)) internal _balances;

    event Logged(address, uint);
    event Initialized();
    event RewardUpdated(uint poolId);

    /**
     * @dev Initialize contract.
     *
     * Permission: Owner
     */
    function initialize(IAliumGaming1155 _rewardToken, address _shp) external onlyOwner {
        require(!initialized, "Reward pool: initialized");
        require(
            address(_rewardToken) != address(0), 
            "Reward zero address"
        );
        require(_shp != address(0), "SHP zero address");

        require(ERC165Checker.supportsERC165(address(_rewardToken)), "ERC165 unsupported token");
        require(ERC165Checker.supportsInterface(address(_rewardToken), type(IAliumGaming1155).interfaceId), "ERC1155 unsupported token");

        rewardToken = _rewardToken;
        shp = _shp;
        initialized = true;
        emit Initialized();
    }

    /**
     * @dev Write to log `_caller` and `_withdrawPosition`.
     *
     * Permission: SHP
     */
    function log(address _caller, uint256 _withdrawPosition) external override onlySHP {
        _logs[_caller][_withdrawPosition] += 1;
        emit Logged(_caller, _withdrawPosition);
    }

    /**
     * @dev Claim available reward.
     */
    function claim() external {
        Reward memory reward;
        uint256[101] memory _userLogs = getLogs(msg.sender);
        for (uint i; i <= 100; i++) {
            if (_userLogs[i] != 0) {
                // clear log data
                delete _logs[msg.sender][i];
                uint ll = _rewards[i].length;
                for (uint ii; ii < ll; ii++) {
                    reward = _rewards[i][ii];
                    rewardToken.mint(
                        address(this),
                        reward.tokenId,
                        reward.amount,
                        ""
                    );
                    try rewardToken.safeTransferFrom(
                        address(this),
                        msg.sender,
                        reward.tokenId,
                        reward.amount,
                        ""
                    ) {
                        //
                    } catch (bytes memory error) {
                        _balances[msg.sender][reward.tokenId] += reward.amount;
                    }
                }
            }
        }
    }

    /**
     * @dev Withdraw available tokens by `_tokenId`.
     */
    function withdraw(uint256 _tokenId) external {
        _withdraw(msg.sender, msg.sender, _tokenId, _balances[msg.sender][_tokenId]);
    }

    /**
     * @dev Withdraw to account `_to` amount `_tokenAmount` tokens with `_tokenId`.
     */
    function withdrawTo(address _to, uint256 _tokenId, uint256 _tokenAmount) external {
        _withdraw(msg.sender, _to, _tokenId, _tokenAmount);
    }

    function _withdraw(address _from, address _to, uint256 _tokenId, uint256 _tokenAmount) private {
        uint balance = _balances[_from][_tokenId];

        require(balance > 0, "Withdraw empty balance");
        require(_tokenAmount >= balance, "Not enough token balance");

        _balances[_from][_tokenId] -= _tokenAmount;
        rewardToken.safeTransferFrom(address(this), _to, _tokenId, balance, "");
    }

    /**
     * @dev Returns `_account` balance by `_tokenId`.
     */
    function getBalance(address _account, uint _tokenId) external view returns (uint256) {
        return _balances[_account][_tokenId];
    }

    /**
     * @dev Returns `_account` log by `_withdrawPosition`.
     */
    function getLog(address _account, uint _withdrawPosition) external view returns (uint256 res) {
        res = _logs[_account][_withdrawPosition];
    }

    /**
     * @dev Returns `_account` logs.
     */
    function getLogs(address _account) public view returns (uint256[101] memory res) {
        uint l = 100;
        uint i = 1;
        for (i; i <= l; i++) {
            res[i] = _logs[_account][i];
        }
    }

    /**
     * @dev Returns reward by `_withdrawPosition`.
     */
    function getReward(uint256 _withdrawPosition) external view returns (Reward[] memory) {
        return _rewards[_withdrawPosition];
    }

    /**
     * @dev Set `_rewardsList` for current `_withdrawPosition`.
     *
     * Permission: owner
     *
     * @notice Reward will be overwritten
     */
    function setReward(
        uint256 _position,
        Reward[] memory _rewardsList
    )
        external
        onlyOwner
    {
        uint l = _rewardsList.length;
        uint i = 0;
        delete _rewards[_position];
        for (i; i < l; i++) {
            _rewards[_position].push(_rewardsList[i]);
        }

        emit RewardUpdated(_position);
    }

    /**
     * @dev Set `_rewardsLists` for selected `_positions`.
     *
     * Permission: owner
     *
     * @notice Reward will be overwritten
     */
    function setRewards(
        uint256[] memory _positions,
        InputReward[] memory _rewardsLists
    )
        external
        onlyOwner
    {
        uint l = _positions.length;

        require(l == _rewardsLists.length, "Incorrect length input data");

        uint i;
        uint ll;
        for (i; i < l; i++) {
            if (_positions[i] > 100 || _positions[i] == 0) {
                require(false, "Wrong position index set");
            }
        }

        i = 0;
        for (i; i < l; i++) {
            if (_rewards[_positions[i]].length != 0) {
                delete _rewards[_positions[i]];
            }

            ll = _rewardsLists[i].rewards.length;
            for (uint ii; ii < ll; ii++) {
                _rewards[_positions[i]].push(_rewardsLists[i].rewards[ii]);
            }

            emit RewardUpdated(_positions[i]);
        }
    }

    modifier onlySHP {
        require(msg.sender == shp, "Only SHP contract");
        _;
    }
}