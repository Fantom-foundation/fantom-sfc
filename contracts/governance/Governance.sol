pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./Proposal.sol";
import "./SoftwareUpgradeProposal.sol";
import "./GovernanceSettings.sol";
import "../common/ImplementationValidator.sol";


contract Governance is GovernanceSettings {
    using SafeMath for uint256;

    uint256 constant choiseYes = 0x01;
    uint256 constant choiseNo = 0x02;
    uint256 constant choiseAbstain = 0x03;

    struct Voter {
        uint256 power;
        uint256 choise;
        address previousDelegation;
    }

    struct ProposalTimeline {
        uint256 depositingStartTime;
        uint256 depositingEndTime;
        uint256 votingStartTime;
        uint256 votingEndTime;
    }

    struct ProposalDescription {
        ProposalTimeline deadlines;
        uint256 id;
        uint256 requiredDeposit;
        uint256 requiredVotesNum;
        uint256 deposit;
        uint256 votes;
        address proposalContract;
        uint256[3] choises;
    }

    Governable governableContract;
    ImplementationValidator implementationValidator;
    uint256 lastProposalId;
    uint256[] public deadlines;

    mapping(uint256 => ProposalDescription) proposals;
    mapping(uint256 => uint256) deposits;
    mapping(uint256 => uint256) proposalRequiredDeposit;
    mapping(uint256 => uint256) votes;
    mapping(uint256 => uint256) proposalRequiredVotes;
    mapping(uint256 => ProposalTimeline) proposalDeadlines;
    mapping(address => mapping(uint256 => uint256)) public depositors;
    mapping(address => mapping(uint256 => Voter)) public voters;
    mapping(uint256 => uint256) public deadlineIdxs;

    event ProposalIsCreated(uint256 proposalId);
    event ProposalIsResolved(uint256 proposalId);
    event ProposalDepositIncreased(address depositor, uint256 proposalId, uint256 value, uint256 newTotalDeposit);
    event StartedProposalVoting(uint256 proposalId);
    event ProposalIsRejected(uint256 proposalId);
    event DeadlinesResolved(uint256 startIdx, uint256 quantity);
    event ResolvedProposal(uint256 proposalId);
    event ImplementedProposal(uint256 proposalId);
    event DeadlineRemoved(uint256 deadline);
    event DeadlineAdded(uint256 deadline);
    event GovernableContractSet(address addr);
    event SoftwareVersionAdded(string version, address addr);
    event VotersPowerReduced(address voter);
    event UserVoted(address voter, uint256 proposalId, uint256 choise, uint256 power);

    function vote(uint256 proposalId, uint256 choise) public {
        ProposalDescription storage prop = proposals[proposalId];

        require(choise >= choiseYes || choiseYes <= choiseAbstain, "impossible choise");
        require(voters[msg.sender][proposalId].power == 0, "this account has already voted. try to cancel a vote if you want to revote");
        require(prop.id == proposalId, "proposal with a given id doesnt exist");
        require(prop.deposit != 0, "proposal didnt enter depositing period");
        require(prop.deposit >= prop.requiredDeposit, "proposal is not at voting period");

        (uint256 ownVotingPower, uint256 delegationVotingPower, uint256 givenAwayVotingPower) = accountVotingPower(msg.sender, prop.id);

        if (ownVotingPower != 0) {
            uint256 power = ownVotingPower + delegationVotingPower - reducedVotersPower[msg.sender][proposalId];
            makeVote(proposalId, choise, power);
        }

        if (givenAwayVotingPower != 0) {
            address delegatedTo = governableContract.delegatedVotesTo(msg.sender);
            recountVoter(proposalId, delegatedTo);
            reduceVotersPower(proposalId, delegatedTo, givenAwayVotingPower);
            makeVote(proposalId, choise, givenAwayVotingPower);
            voters[msg.sender][proposalId].previousDelegation = delegatedTo;
        }
    }

    function increaseProposalDeposit(uint256 proposalId) public payable {
        ProposalDescription storage prop = proposals[proposalId];

        require(prop.id == proposalId, "proposal with a given id doesnt exist");
        require(statusDepositing(prop.status), "proposal is not depositing");
        require(msg.value > 0, "msg.value is zero");
        require(block.timestamp > prop.deadlines.depositingEndTime, "cannot deposit to an overdue proposal");

        prop.deposit += msg.value;
        depositors[msg.sender][prop.id] += msg.value;
        emit ProposalDepositIncreased(msg.sender, proposalId, msg.value, prop.deposit);
    }

    function createProposal(address proposalContract, uint256 requiredDeposit, bytes32[] choises) public payable {
        validateProposalContract(proposalContract);
        require(msg.value >= minimumStartingDeposit();

        uint256 reqDeposit;
        if (requiredDeposit >= minimumDeposit()) {
            reqDeposit = requiredDeposit;
        } else {
            reqDeposit = minimumDeposit();
        }

        lastProposalId++;    
        ProposalDescription storage prop = proposals[lastProposalId];
        prop.id = lastProposalId;
        prop.requiredDeposit = reqDeposit;
        prop.requiredVotesNum = minimumVotesRequired();
        prop.deposit = msg.value;
    }

    function validateProposalContract(address proposalContract) public {

    }

    function handleDeadlines(uint256 startIdx, uint256 endIdx) public {
        require(startIdx <= endIdx, "incorrect indexes passed");

        for (uint256 i = startIdx; i < endIdx; i++) {
            handleDeadline(deadlines[i]);
        }

        emit DeadlinesResolved(startIdx, endIdx);
    }

    function handleDeadline(uint256 deadline) public {

        uint256[] memory proposalIds = proposalsAtDeadline[deadline];
        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];
            handleProposalDeadline(proposalId);
        }

        uint256 idx = deadlineIdxs[deadline];
        uint256 deadlineToDelete = deadlines[idx];
        deadlines[idx] = deadlines[deadlines.length - 1];
        deadlineIdxs[deadlines[idx]] = idx;
        deadlines.length--;

        emit DeadlineRemoved(deadlineToDelete);
    }

    function handleProposalDeadline(uint256 proposalId) public {
        Proposal storage prop = proposals[proposalId];
        if (statusDepositing(prop.status)) {
            if (prop.deposit >= prop.requiredDeposit) {
                proceedToVoting(prop.id);
                return;
            }
        }

        if (statusVoting(prop.status)) {
            if (prop.totalVotes >= prop.minVotesRequired) {
                resolveProposal(prop.id);
                return;
            }
        }

        failProposal(prop.id);
    }

    function makeVote(uint256 proposalId, uint256 choise, uint256 power) internal {
        ProposalDescription storage prop = proposals[proposalId];

        Voter storage voter = voters[msg.sender][proposalId];
        voter.choise = choise;
        voter.power = power;

        prop.choises[choise] += power;
        prop.votes += power;
        emit UserVoted(msg.sender, proposalId, choise, power, prop.votes);
    }

    function recountVoter(uint256 proposalId, address voterAddr) internal {
        Voter memory voter = voters[voterAddr][proposalId];
        Proposal storage prop = proposals[proposalId];
        cancelVote(proposalId, voterAddr);

        (uint256 ownVotingPower, uint256 delegationVotingPower, uint256 givenAwayVotingPower) = accountVotingPower(voterAddr, prop.id);
        uint256 power;
        if (ownVotingPower > 0) {
            power = ownVotingPower + delegationVotingPower - reducedVotersPower[voterAddr][proposalId];
        }
        if (givenAwayVotingPower > 0) {
            power = givenAwayVotingPower + delegationVotingPower - reducedVotersPower[voterAddr][proposalId];
        }

        makeVote(proposalId, voter.choise, power);
    }

    function reduceVotersPower(uint256 proposalId, address voter, uint256 power) internal {
        uint256 choise = voters[voter][proposalId].choise;

        Proposal storage prop = proposals[proposalId];
        prop.choises[choise] -= power;
        voters[voter][proposalId].power -= power;
        reducedVotersPower[voter][proposalId] += power;
        emit VotersPowerReduced(voter);
    }
}