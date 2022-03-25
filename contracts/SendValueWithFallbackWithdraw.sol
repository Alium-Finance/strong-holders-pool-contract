// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @notice Attempt to send ETH and if the transfer fails or runs out of gas, store the balance
 * for future withdrawal instead.
 */
abstract contract SendValueWithFallbackWithdraw {
    mapping(address => uint256) private pendingWithdrawals;

    event Withdrawal(address indexed _user, uint256 _amount);
    event WithdrawPending(address indexed _user, uint256 _amount);

    /**
     * @notice Returns how much funds are available for manual withdraw due to failed transfers.
     */
    function getPendingWithdrawal(address _user) public view returns (uint256) {
        return pendingWithdrawals[_user];
    }

    /**
     * @notice Allows a user to manually withdraw funds which originally failed to transfer.
     */
    function withdrawPending() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds are pending withdrawal");
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{ value: amount, gas: 21000 }("");
        require(success, "Ether withdraw failed");
        emit Withdrawal(msg.sender, amount);
    }

    function _sendValueWithFallbackWithdraw(address _user, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }

        // Cap the gas to prevent consuming all available gas to block a tx from completing successfully
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = _user.call{ value: _amount, gas: 21000 }("");

        if (!success) {
            // Record failed sends for a withdrawal later
            // Transfers could fail if sent to a multisig with non-trivial receiver logic
            unchecked {
                pendingWithdrawals[_user] += _amount;
            }

            emit WithdrawPending(_user, _amount);
        } else {
            emit Withdrawal(_user, _amount);
        }
    }
}