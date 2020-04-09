pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";


contract Governance is Constants {
    using SafeMath for uint256;

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

    uint256 lastProposalId;

    // should we set a limit of active and inactive proposals
    uint256[] activeProposalIds;
    uint256[] preActiveProposalIds;

    // maps proposal id to an active proposal
    mapping(uint256 => Proposal) public activeProposals;
    // maps proposal id to a pre-active proposals. pre active proposal is a proposal which deposit is not filled yet
    mapping(uint256 => Proposal) public preActiveProposals;

    event ProposalIsCreated(uint256 proposalId);
    event ProposalIsResolved(uint256 proposalId);
    event ProposalIsRejected(uint256 proposalId, uint256 reason);

    function createSoftwareUpgradeProposal(string memory description, string memory version, uint256 minDeposit) public {
        lastProposalId++;

        Proposal memory prop;
        prop.id = lastProposalId;
        prop.description = description;
        prop.minDeposit = minDeposit;
        prop.proposalSpecialData = bytes(version);
        prop.propType = typeSoftwareUpgrade();

        emit ProposalIsCreated(prop.id);
    }
}