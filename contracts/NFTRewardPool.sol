/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAliumGaming1155.sol";
import "./interfaces/INFTRewardPool.sol";

contract NFTRewardPool is INFTRewardPool, Ownable {

    struct Reward {
        uint256 tokenId;
        uint256 amount;
    }

    struct SetRewardInput {
        uint256 position;
        Reward[] rewards;
    }

    bool public status;

    IAliumGaming1155 public rewardToken;

    mapping (uint256 => Reward[]) private _rewards;
    // pool id -> withdraw position -> counter
    mapping (address => mapping (uint256 => uint256)) private _logs;
    mapping (address => mapping (uint256 => uint256)) private _balances;

    constructor(IAliumGaming1155 _rewardToken) {
        require(address(_rewardToken) != address(0), "Reward zero address");

        rewardToken = _rewardToken;
    }

    function log(address _caller, uint256 _withdrawPosition) external override {
        _logs[_caller][_withdrawPosition] += 1;
    }

    function claim() external {
//        uint tokenId;
//        uint amount;
        Reward memory reward;
        uint256[100] memory __logs = getLogs(msg.sender);
        for (uint i; i <= 100; i++) {
            if (__logs[i] != 0) {
                uint ll = _rewards[i].length;
                for (uint ii; ii < ll; ii++) {
                    reward = _rewards[i][ii];
                    IAliumGaming1155(rewardToken).mint(
                        address(this),
                        reward.tokenId,
                        reward.amount,
                        ""
                    );
                    try IAliumGaming1155(rewardToken).safeTransferFrom(
                        address(this),
                        msg.sender,
                        reward.tokenId,
                        reward.amount,
                        ""
                    ) {
                        //
                    } catch (bytes memory error) {
                        _balances[msg.sender][reward.amount] += reward.amount;
                    }
                }
            }
        }
    }

    function withdraw(address _account, uint256 _tokenId) external {
        uint balance = _balances[_account][_tokenId];
        _balances[_account][_tokenId] -= balance;
        IAliumGaming1155(rewardToken).safeTransferFrom(address(this), _account, _tokenId, balance, "");
    }

    // call contract
    function getLog(address _account, uint _withdrawPosition) public view returns (uint256 res) {
        res = _logs[_account][_withdrawPosition];
    }

    function getLogs(address _account) public view returns (uint256[100] memory res) {
        uint l = 100;
        uint i = 1;
        for (i; i <= l; i++) {
            res[i] = _logs[_account][i];
        }
    }

    function getReward(uint256 _withdrawPosition) external view returns (Reward[] memory) {
        return _rewards[_withdrawPosition];
    }

    function setReward(
        uint256 _position,
        Reward[] memory __rewards
    ) external {
        uint l = __rewards.length;
        uint i;
        for (i; i < l; i++) {
            _rewards[_position][i] = __rewards[i];
        }
    }

//    function setRewards(SetRewardInput[] memory _input) external view returns () {
//        return ;
//    }
}