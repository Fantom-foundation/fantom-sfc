pragma solidity ^0.5.0;

import "./Roles.sol";


contract WhitelistedRecipientRole {
    using Roles for Roles.Role;

    event WhitelistedRecipientAdded(address indexed account);
    event WhitelistedRecipientRemoved(address indexed account);

    Roles.Role private whitelistedRecipients;

    modifier onlyWhitelistedRecipient() {
        require(isWhitelistedRecipient(msg.sender));
        _;
    }

    function isWhitelistedRecipient(address account) public view returns (bool) {
        return whitelistedRecipients.has(account);
    }

    function renounceWhitelistedRecipient() public {
        whitelistedRecipients.remove(msg.sender);
    }

    function _removeWhitelistedRecipient(address account) internal {
        whitelistedRecipients.remove(account);
        emit WhitelistedRecipientRemoved(account);
    }

    function _addWhitelistedRecipient(address account) internal {
        whitelistedRecipients.add(account);
        emit WhitelistedRecipientAdded(account);
    }

    uint256[50] private ______gap;
}
