/// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVersioned.sol";

// @title VersionControl - front end version control feature
abstract contract VersionControl is IVersioned, Ownable {
    bytes32 public override version;

    constructor(bytes32 _version) {
        version = _version;
    }

    function setVersion(bytes32 _newVersionHash) external override onlyOwner {
        version = _newVersionHash;
        emit VersionUpdated(_newVersionHash);
    }

    function countVersion(string memory _data) external view onlyOwner returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(_data));
    }
}