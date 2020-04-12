
pragma solidity ^0.5.0;

import "./SafeMath.sol";


contract Constants {
    using SafeMath for uint256;

    // types
    uint256 constant TYPE_SOFTWARE_UPGRADE = 0x1; // software upgrade type
    uint256 constant TYPE_PLAIN_TEXT = 0x2; // plane text type
    uint256 constant TYPE_IMMEDIATE_ACTION = 0x3; // immediate action type

    // bit map
    uint256 constant BIT_IS_ACTIVE = 0;
    uint256 constant BIT_IS_FROSEN = 1;
    uint256 constant BIT_IS_VOTING = 2;
    uint256 constant BIT_IS_ACCEPTED = 3;
    uint256 constant BIT_IS_FAILED = 4;
    uint256 constant BIT_IS_IMPLEMENTED = 5;

    // statuses
    uint256 constant ACTIVE = 1;
    uint256 constant STATUS_DEPOSITING = ACTIVE;
    uint256 constant STATUS_DEPOSITING_FAILED = failStatus(STATUS_DEPOSITING);
    uint256 constant STATUS_VOTING = setStatusVoting(ACTIVE);
    uint256 constant STATUS_VOTING_FAILED = failStatus(STATUS_VOTING);

    function makeStatusActive(uint256 status) public pure returns (uint256) {
        status |= 1 << BIT_IS_ACTIVE;
        return status;
    }

    function failStatus(uint256 status) public pure returns (uint256) {
        status &= ~(1 << BIT_IS_ACTIVE);
        status &= ~(1 << BIT_IS_ACCEPTED);
        status &= ~(1 << BIT_IS_IMPLEMENTED);
        return status;
    }

    function setStatusVoting(uint256 status) public pure returns (uint256) {
        status |= 1 << BIT_IS_VOTING;
        return status;
    }

    function typeSoftwareUpgrade() public pure returns (uint256) {
        return TYPE_SOFTWARE_UPGRADE;
    }

    function typePlainText() public pure returns (uint256) {
        return TYPE_PLAIN_TEXT;
    }

    function typeImmediateAction() public pure returns (uint256) {
        return TYPE_IMMEDIATE_ACTION;
    }

    // creates special data for a software upgrade proposal
    function makeSUData(string memory version) internal pure returns (bytes memory) {
        return bytes(version);
    }

    function statusActive(uint256 status) internal pure returns (bool) {
        return (status >> BIT_IS_ACTIVE) & 1 == 1;
    }

    function statusInactive(uint256 status) internal pure returns (bool) {
        return (status >> BIT_IS_ACTIVE) & 1 == 0;
    }

    function statusDepositing(uint256 status) internal pure returns (bool) {
        return status & STATUS_DEPOSITING == STATUS_DEPOSITING;
    }

    function statusDepositingFailed(uint256 status) internal pure returns (bool) {
        return status & STATUS_DEPOSITING_FAILED == STATUS_DEPOSITING_FAILED;
    }

    function statusActiveVoting(uint256 status) internal pure returns (bool) {
        return status & STATUS_VOTING == STATUS_VOTING;
    }

    function statusVotingFailed(uint256 status) internal pure returns (bool) {
        return status & STATUS_VOTING_FAILED == STATUS_VOTING_FAILED;
    }
}