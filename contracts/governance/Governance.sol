pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";


// add non reentrant!!
contract Governance is Constants {
    using SafeMath for uint256;

    struct ProposalDeadlint {
        uint256 id;
        uint256 deadline;
    }

    struct ProposalTimelines {
        uint256 depositingStartTime;
        uint256 depositingEndTime;
        uint256 votingStartEpoch;
        uint256 votingEndEpoch;
        uint256 votingStartTime;
        uint256 votingEndTime;
    }

    struct Proposal {
        uint256 id;
        uint256 propType;
        uint256 status; // status is a bitmask, check out "constants" for a further info
        uint256 minDeposit;
        uint256 deposit;
        ProposalTimelines timelines

        string description;
        bytes proposalSpecialData;
    }

    uint256 lastProposalId;
    uint256 earliestActiveEndtime;
    uint256 earliestPreActiveEndtime;

    // TODO: should we set a limit of active and inactive proposals ?
    uint256[] votingProposalIds;
    uint256[] depositingProposalIds;
    uint256[] inactiveProposalIds; // inactive proposal is a proposal that once became active, but was eventualy rejected
    uint256[] proposalDeadlines;
    uint256[] deadlines;

    address ADMIN;

    mapping(uint256 => uint256) public deadlineMap;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => []uint256)) public proposalCreators; // maps proposal id to a voter and its voting power
    mapping(uint256 => mapping(address => uint256)) public depositors; // maps proposal id to a sender and deposit
    mapping(uint256 => mapping(address => uint256)) public voters; // maps proposal id to a voter and its voting power

    event ProposalIsCreated(uint256 proposalId);
    event ProposalIsResolved(uint256 proposalId);
    event ProposalIsRejected(uint256 proposalId, uint256 reason);

    function maxProposalsPerUser() public view returns (uint256) {
        return 1;
    }

    function canCreateProposal(address addr) public returns (bool) {
        if (addr == ADMIN) {
            return true;
        }
        return proposalCreators[msg.sender].length < maxProposalsPerUser();
    }

    function ensureProposalCanBeCreated(address addr) public {
        if (addr == ADMIN) {
            return;
        }

        require(proposalCreators[addr].length < maxProposalsPerUser(), "maximum created proposal limit for a user exceeded");
        require(canCreateProposal(addr), "address has no permissions to create new proposal");
    }

    function pushNewProposal(Proposal memory prop) {
        proposals[prop.id] = prop;
    }

    function createSoftwareUpgradeProposal(string memory description, string memory version, uint256 minDeposit) public {
        ensureProposalCanBeCreated(msg.sender);
        lastProposalId++;

        Proposal memory prop;
        prop.id = lastProposalId;
        prop.description = description;
        prop.minDeposit = minDeposit;
        prop.proposalSpecialData = makeSUData(version);
        prop.propType = typeSoftwareUpgrade();
        pushNewProposal(prop);

        emit ProposalIsCreated(prop.id);
    }

    function increaseProposalDeposit(uint256 proposalId) public payable {
        Proposal storage prop = proposals[proposalId];

        require(prop.id != 0, "proposal with a given id doesnt exist");
        require(statusDepositing(prop.status), "proposal is not depositing");
        require(msg.value > 0, "msg.value is zero");
        if (block.timestamp > prop.depositingEndTime) {
            // deactivateProposal(prop);
            revert("cannot deposit to an overdue proposal");
        }

        prop.deposit = prop.deposit.add(msg.value);
        depositors[prop.id][msg.sender] = depositors[prop.id][msg.sender].add(msg.value);
    }

    function deactivateProposal(Proposal storage prop) public {
        bool foundProposal;
        if (statusDepositing(prop.status)) {
            deactivateDepositingProposal(prop);
        }
    }

    function deactivateDepositingProposal(Proposal storage prop) public {
        bool foundProposal;
        for (uint256 i = 0; i < depositingProposalIds.length; i++) {
            if (depositingProposalIds[i] == prop.id) {
                foundProposal = true;
                delete depositingProposalIds[i];
                break;
            }
            if (foundProposal) {
                depositingProposalIds[i] = depositingProposalIds[i + 1];
            }
        }

        if (foundProposal) {
            revert("proposal is not present in an array");
        }

        depositingProposalIds[i].length--;
        prop.status = failStatus(prop.status);
        inactiveProposalIds.push(prop.id);
    }
}