pragma solidity ^0.5.0;

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

    struct ProposalTimeline {
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
        mapping (uint256 => uint256) choises;

        ProposalTimeline deadlines;

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

    mapping(uint256 => uint256) deadlineIdxs;
    mapping(uint256 => uint256[]) proposalsAtDeadline;
    mapping(uint256 => Proposal) proposals;
    mapping(address => mapping(uint256 => address)) delegators; // delegation from address to another address at some proposalId
    mapping(address => mapping(uint256 => address[])) delegations; // delegation from address to another address at some proposalId
    mapping(address => uint256[]) proposalCreators; // maps proposal id to a voter and its voting power
    mapping(uint256 => mapping(address => uint256)) depositors; // maps proposal id to a sender and deposit
    mapping(address => mapping(uint256 => uint256)) voters; // maps proposal id to a voter and its voting power

    event ProposalIsCreated(uint256 proposalId);
    event ProposalIsResolved(uint256 proposalId);
    event ProposalIsRejected(uint256 proposalId, uint256 reason);
    event DeadlinesResolved(uint256 startIdx, uint256 quantity);
    event ResolvedProposal(uint256 proposalId);
    event ImplementedProposal(uint256 proposalId);
    event DeadlineRemoved(uint256 deadline);
    event DeadlineAdded(uint256 deadline);

    function maxProposalsPerUser() public view returns (uint256) {
        return 1;
    }

    function accountVotingPower(address acc, uint256 proposalId) public view returns (uint256) {
        return 1;
    }

    function vote(uint256 proposalId, uint256 choise) public {
        ensureAccountCanVote(msg.sender);

        Proposal storage prop = proposals[proposalId];

        require(voters[msg.sender][proposalId] == 0, "this account has already voted. try to cancel a vote if you want to revote");
        require(delegators[msg.sender][proposalId] == address(0), "this account has delegated a vote. try to cancel a delegation");
        require(prop.id == proposalId, "cannot find proposal with a passed id");
        require(statusVoting(prop.status), "cannot vote for a given proposal");

        address[] memory delegatedAddresses = delegations[msg.sender][proposalId];
        uint256 additionalVotingPower;
        for (uint256 i = 0; i<delegatedAddresses.length; i++) {
            additionalVotingPower = additionalVotingPower.add(accountVotingPower(msg.sender, prop.id));
        }

        prop.choises[choise] += accountVotingPower(msg.sender, prop.id).add(additionalVotingPower);

        voters[msg.sender][proposalId] = choise;
        revert("could not find choise among proposal possible choises");
    }

    function cancelVote(uint256 proposalId) public {
        Proposal storage prop = proposals[proposalId];
        require(prop.votesCanBeCanceled, "votes cannot be canceled due to proposal settings");
        require(delegators[msg.sender][proposalId] == address(0), "sender has delegated his vote");

        voters[msg.sender][proposalId] = 0;
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
        emit DeadlineAdded(deadlines[idx]);
    }

    function handleProposalDeadline(uint256 proposalId) public {
        Proposal storage prop = proposals[proposalId];
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

    function createSoftwareUpgradeProposal(string memory description, string memory version) public {
        ensureProposalCanBeCreated(msg.sender);
        createNewProposal(
            description,
            version,
            makeSUData(version),
            typeSoftwareUpgrade());
    }

    function createNewProposal(
        string memory description,
        string memory version,
        bytes memory proposalSpecialData,
        uint256 proposalType) internal
    {
        lastProposalId++;

        Proposal memory prop;
        prop.id = lastProposalId;
        prop.description = description;
        prop.minDeposit = minimumDeposit(proposalType);
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
        require(block.timestamp > prop.deadlines.depositingEndTime, "cannot deposit to an overdue proposal");

        prop.deposit = prop.deposit.add(msg.value);
        depositors[prop.id][msg.sender] = depositors[prop.id][msg.sender].add(msg.value);
    }

    function resolveProposal(uint256 proposalId) internal {
        // todo: implement logic below
        emit ResolvedProposal(proposalId);
    }

    function ensureAccountCanVote(address acc) internal {
        if (acc == ADMIN) {
            return;
        }

        return;
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

    function finalizeProposalVoting(uint256 proposalId) internal {

    }

    function pushNewProposal(Proposal memory prop) internal {
        proposals[prop.id] = prop;

    }

    function addNewDeadline(uint256 deadline) internal {
        deadlines.push(deadline);
        deadlineIdxs[deadline] = deadlines.length - 1;

    }

    // creates special data for a software upgrade proposal
    function makeSUData(string memory version) internal pure returns (bytes memory) {
        return bytes(version);
    }

    //function insertToDeadlines(uint256 idx, uint256 deadline) internal {
    //    deadlines.push(deadline);
    //    deadlineIdxs[deadlines.length - 1]
    //
    //    for (uint256 i = idx; i < deadlines.length; i++) {
    //
    //    }
    //}
}