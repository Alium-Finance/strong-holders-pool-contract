/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

interface IVersioned {
    function version() external view returns (bytes32 hash);

    function setVersion(bytes32 newVersionHash) external;

    event VersionUpdated(bytes32);
}
