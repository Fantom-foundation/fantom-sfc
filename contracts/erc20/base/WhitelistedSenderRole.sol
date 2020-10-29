pragma solidity ^0.5.0;

import "./Roles.sol";


contract WhitelistedSenderRole {
    using Roles for Roles.Role;

    event WhitelistedSenderAdded(address indexed account);
    event WhitelistedSenderRemoved(address indexed account);

    Roles.Role private whitelistedSenders;

    modifier onlyWhitelistedSender() {
        require(isWhitelistedSender(msg.sender));
        _;
    }

    function isWhitelistedSender(address account) public view returns (bool) {
        return whitelistedSenders.has(account);
    }

    function renounceWhitelistedSender() public {
        whitelistedSenders.remove(msg.sender);
    }

    function _removeWhitelistedSender(address account) internal {
        whitelistedSenders.remove(account);
        emit WhitelistedSenderRemoved(account);
    }

    function _addWhitelistedSender(address account) internal {
        whitelistedSenders.add(account);
        emit WhitelistedSenderAdded(account);
    }

    uint256[50] private ______gap;
}
