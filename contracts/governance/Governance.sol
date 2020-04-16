pragma solidity ^0.6.0;

import "./SafeMath.sol";
import "./Constants.sol";


// add non reentrant!!
contract Governance is Constants {
    using SafeMath for uint256;

    struct Choise {
        uint8 id; // choise id cannot be less than 1
        uint256 votes;
    }

    struct ProposalDeadline {
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
        uint256 permissionsRequired; // might be a bitmask?
        uint256 minVotesRequired;
        uint256 totalVotes;
        Choise[] possibleChoises;

        ProposalTimelines timelines;

        string description;
        bytes proposalSpecialData;
        bool votesCanBeCanceled;
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

    mapping(uint256 => uint256) public deadlineIdxs;
    mapping(uint256 => uint256[]) public proposalsAtDeadline;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => mapping(uint256 => address)) public delegators; // delegation from address to another address at some proposalId
    mapping(address => mapping(uint256 => address[])) public delegations; // delegation from address to another address at some proposalId
    mapping(address => uint256[]) public proposalCreators; // maps proposal id to a voter and its voting power
    mapping(uint256 => mapping(address => uint256)) public depositors; // maps proposal id to a sender and deposit
    mapping(address => mapping(uint256 => uint256)) public voters; // maps proposal id to a voter and its voting power

    event ProposalIsCreated(uint256 proposalId);
    event ProposalIsResolved(uint256 proposalId);
    event ProposalIsRejected(uint256 proposalId, uint256 reason);
    event DeadlinesResolved(uint256 startIdx, uint256 quantity);
    event ResolvedProposal(uint256 proposalId);
    event ImplementedProposal(uint256 proposalId);

    function maxProposalsPerUser() public view returns (uint256) {
        return 1;
    }

    function accountVotingPower(address acc, uint256 proposalId) public view returns (uint256) {
        return 1;
    }

    function ensureAccountCanVote(address acc) {
        if (acc == ADMIN) {
            return;
        }

        return;
    }

    function vote(uint256 proposalId, uint256 choise) public {
        ensureAccountCanVote(msg.sender);

        Proposal storage prop = proposals[proposalId];

        require(voters[msg.sender][proposalId] == 0, "this account has already voted. try to cancel a vote if you want to revote");
        require(delegators[msg.sender][proposalId] == address(0), "this account has delegated a vote. try to cancel a delegation");
        require(prop.id == proposalId, "cannot find proposal with a passed id");
        require(statusActiveVoting(prop.status), "cannot vote for a given proposal");

        address[] delegatedAddresses = delegations[msg.sender][proposalId];
        uint256 additionalVotingPower;
        for (int8 i = 0; i<delegatedAddresses.length; i++) {
            additionalVotingPower = additionalVotingPower.add(accountVotingPower(msg.sender, prop.id));
        }

        for (int8 i = 0; i<prop.possibleChoises.length; i++) {
            if (prop.possibleChoises[i].id == choise) {
                prop.possibleChoises[i].votes += accountVotingPower(msg.sender, prop.id).add(additionalVotingPower);
                prop.possibleChoises[i].totalVotes++;
                return;
            }
        }

        voters[msg.sender][proposalId] = choise;
        revert("could not find choise among proposal possible choises");
    }

    function cancelVote(uint256 proposalId) public {
        Proposal storage prop = proposals[proposalId];
        require(prop.votesCanBeCanceled, "votes cannot be canceled due to proposal settings");
        require(delegators[msg.from][proposalId] == address(0), "sender has delegated his vote");

        voters[msg.sender][proposalId] = 0;
    }

    function handleDeadlines(uint256 startIdx, uint256 endIdx) public {
        require(startIdx <= endIdx, "incorrect indexes passed");

        for (int i = startIdx; i < endIdx; i++) {
            handleDeadline(deadlines[i]);
        }

        emit DeadlinesResolved(startIdx, endIdx);
    }

    function handleDeadline(uint256 deadline) public {
        uint256 idx = deadlineIdxs[deadline];
        delete deadlines[idx];
        uint256[] proposalIds = proposalsAtDeadline[deadline];
        for (int i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];
            handleProposalDeadline(proposalId);
        }
    }

    function handleProposalDeadline(uint256 proposalId) {
        Proposal memory prop = proposals[proposalId];
        if (statusDepositing(prop.status)) {
            if (prop.deposit >= prop.minDeposit) {
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

    function resolveProposal(uint256 proposalId) {
        // todo: implement logic below
        emit ResolvedProposal(proposalId);
    }

    function proceedToVoting(uint256 proposalId) internal {
        Proposal storage prop = proposals[proposalId];
        prop.status = setStatusVoting(prop.status);
    }

    function failProposal(uint256 proposalId) internal {
        Proposal storage prop = proposals[proposalId];
        prop.status = failStatus(prop.status);
        inactiveProposalIds.push(prop.id);
    }

    function finalizeProposalVoting(uint256 proposalId) {

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

    function pushNewProposal(Proposal memory prop) internal {
        proposals[prop.id] = prop;

    }

    function addNewDeadline(uint256 deadline) {
        for (uint256 i = deadlines.length; i > 0; i--) {
            if (deadlines[i] < block.timestamp) {

            }
        }
    }

    function insertToDeadlines(uint256 idx, uint256 dedline) {
        deadlines.push(dedline);

        for (uint256 i = idx; i < deadlines.length; i++) {

        }
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
        require(block.timestamp > prop.depositingEndTime, "cannot deposit to an overdue proposal");

        prop.deposit = prop.deposit.add(msg.value);
        depositors[prop.id][msg.sender] = depositors[prop.id][msg.sender].add(msg.value);
    }

    function deactivateProposal(Proposal storage prop) public {
        bool foundProposal;
        if (statusDepositing(prop.status)) {
            deactivateDepositingProposal(prop);
        }
        if (statusVoting(prop.status)) {
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