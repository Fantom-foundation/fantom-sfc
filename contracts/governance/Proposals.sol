pragma solidity ^0.5.0;

import "./SafeMath.sol";


contract Proposals {
    using SafeMath for uint256;
    uint256 constant TYPE_SOFTWARE_UPGRADE = 1; // software upgrade type
    uint256 constant TYPE_PLAIN_TEXT = 2; // plane text type
    uint256 constant TYPE_IMMEDIATE_ACTION = 3; // immediate action type

    function typeSoftwareUpgrade() public pure returns (uint256) {
        return TYPE_SOFTWARE_UPGRADE;
    }

    function typePlainText() public pure returns (uint256) {
        return TYPE_PLAIN_TEXT;
    }

    function typeImmediateAction() public pure returns (uint256) {
        return TYPE_IMMEDIATE_ACTION;
    }

    struct ProposalProperties {
        uint256 id;
        string description;
        uint256 minDeposit;
    }

    struct SoftwareUpgrade {
        ProposalProperties properties;
        string targetVersion;
    }

    struct PlainText {
        ProposalProperties description;
    }

    struct ImmediateAction {
        ProposalProperties description;
    }

    struct Proposal {
        uint256 id;
        uint256 propType;
        uint256 minDeposit;
        uint256 actualDeposit;

        uint256 votingStartEpoch;
        uint256 votingEndEpoch;
        uint256 votingStartTime;
        uint256 votingEndTime;

        string description;
        bytes proposalSpecialData;
    }
}