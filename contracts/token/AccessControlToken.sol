/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract AccessControlToken is AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Overload {grantRole} to track enumerable memberships.
     */
    function grantRole(bytes32 _role, address _account)
        public
        override
        onlyRole(ADMIN_ROLE)
    {
        super.grantRole(_role, _account);
    }

    /**
     * @dev Overload {revokeRole} to track enumerable memberships.
     */
    function revokeRole(bytes32 _role, address _account)
        public
        override
        onlyRole(ADMIN_ROLE)
    {
        super.revokeRole(_role, _account);
    }

    /**
     * @dev Overload {renounceRole} to track enumerable memberships.
     */
    function renounceRole(bytes32 _role, address _account)
        public
        override
    {
        require(hasRole(_role, _account), "You has no role");

        super.renounceRole(_role, _msgSender());
    }
}
