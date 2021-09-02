// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;

import "../LibPart.sol";

abstract contract AbstractRoyalties {
    mapping (uint256 => LibPart.Part[]) internal _royalties;

    function _saveRoyalties(uint256 id, LibPart.Part[] memory _royalties_) internal {
        uint256 totalValue;
        for (uint i = 0; i < _royalties_.length; i++) {
            require(_royalties_[i].account != address(0x0), "Recipient should be present");
            require(_royalties_[i].value != 0, "Royalty value should be positive");
            totalValue += _royalties_[i].value;
            _royalties[id].push(_royalties_[i]);
        }
        require(totalValue < 10000, "Royalty total value should be < 10000");
        _onRoyaltiesSet(id, _royalties_);
    }

    function _updateAccount(uint256 _id, address _from, address _to) internal {
        uint length = _royalties[_id].length;
        for(uint i = 0; i < length; i++) {
            if (_royalties[_id][i].account == _from) {
                _royalties[_id][i].account = payable(_to);
            }
        }
    }

    function _onRoyaltiesSet(uint256 id, LibPart.Part[] memory _royalties_) virtual internal;
}
