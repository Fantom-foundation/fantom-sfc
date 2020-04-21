pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./ProposalHandler.sol";
import "./SoftwareUpgradeProposal.sol";
import "../common/ImplementationValidator.sol";


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
        uint256 deposit;
        uint256 requiredDeposit;
        uint256 permissionsRequired; // might be a bitmask?
        uint256 minVotesRequired;
        uint256 totalVotes;
        mapping (uint256 => uint256) choises;

        ProposalTimeline deadlines;

        string title;
        string description;
        bytes proposalSpecialData;
        bool votesCanBeCanceled;
    }

    struct Voter {
        uint256 power;
        uint256 choise;
        address previousDelegation;
    }

    struct Depositor {
        uint256 depositedAmount;
    }

    Governable governableContract;
    ImplementationValidator implementationValidator;
    SoftwareUpgradeProposalHandler sopHandler;

    address ADMIN;
    uint256[] deadlines;
    uint256[] inactiveProposalIds;
    uint256 lastProposalId;

    mapping(uint256 => Proposal) proposals;
    mapping(address => mapping(uint256 => Voter)) voters;
    mapping(address => mapping(uint256 => Depositor)) depositors;
    mapping(address => mapping(uint256 => uint256)) reducedVotersPower;
    mapping(uint256 => uint256) deadlineIdxs;
    mapping(uint256 => uint256[]) proposalsAtDeadline;
    mapping(address => uint256[]) proposalCreators; // maps proposal id to a voter and its voting power

    event ProposalIsCreated(uint256 proposalId);
    event ProposalIsResolved(uint256 proposalId);
    event ProposalIsRejected(uint256 proposalId, uint256 reason);
    event DeadlinesResolved(uint256 startIdx, uint256 quantity);
    event ResolvedProposal(uint256 proposalId);
    event ImplementedProposal(uint256 proposalId);
    event DeadlineRemoved(uint256 deadline);
    event DeadlineAdded(uint256 deadline);
    event GovernableContractSet(address addr);

    constructor() public {
        string[] memory methodsOfAContract = [];
        implementationValidator = new ImplementationValidator(methodsOfAContract);
    }

    function vote(uint256 proposalId, uint256 choise) public {
        Proposal storage prop = proposals[proposalId];

        require(voters[msg.sender][proposalId].power == 0, "this account has already voted. try to cancel a vote if you want to revote");
        // require(delegators[msg.sender][proposalId] == address(0), "this account has delegated a vote. try to cancel a delegation");
        require(prop.id == proposalId, "cannot find proposal with a passed id");
        require(statusVoting(prop.status), "cannot vote for a given proposal");

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

    function setGovernableContract(address newImplementation) internal {
        implementationValidator.checkContractIsValid(newImplementation);
        governableContract = Governable(newImplementation);

        emit GovernableContractSet(newImplementation);
    }

    function makeVote(uint256 proposalId, uint256 choise, uint256 power) public {
        Proposal storage prop = proposals[proposalId];

        Voter storage voter = voters[msg.sender][proposalId];
        voter.choise = choise;
        voter.power = power;

        prop.choises[choise] += power;
        // voters[msg.sender][proposalId] = voter;
    }

    function cancelVote(uint256 proposalId, address voterAddr) public {
        Voter memory voter = voters[voterAddr][proposalId];
        Proposal storage prop = proposals[proposalId];

        prop.choises[voter.choise] -= voter.power;
        if (voters[voterAddr][proposalId].previousDelegation != address(0)) {
            increaseVotersPower(proposalId, voterAddr, voter.power);
        }
        delete voters[voterAddr][proposalId];
    }

    function recountVoter(uint256 proposalId, address voterAddr) public {
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

    function accountVotingPower(address acc, uint256 proposalId) public view returns (uint256, uint256, uint256) {
        Proposal memory prop = proposals[proposalId];
        if (prop.propType == typeSoftwareUpgrade()) {
            return governableContract.softwareUpgradeVotingPower(acc);
        }

        if (prop.propType == typePlainText()) {
            return governableContract.plainTextVotingPower(acc);
        }

        if (prop.propType == typeImmediateAction()) {
            return governableContract.immediateActionVotingPower(acc);
        }

        return (0, 0, 0);
    }

    function totalVotersNum(uint256 proposalType) public view returns (uint256) {
        // temprorary constant
        if (proposalType == typeSoftwareUpgrade()) {
            return governableContract.softwareUpgradeTotalVoters();
        }

        if (proposalType == typePlainText()) {
            return governableContract.plainTextTotalVoters();
        }

        if (proposalType == typeImmediateAction()) {
            return governableContract.immediateActionTotalVoters();
        }

        return 0;
    }

    // TODO: should this be a part of governableContract interface?
    function maxProposalsPerUser() public view returns (uint256) {
        return 1;
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

    function increaseProposalDeposit(uint256 proposalId) public payable {
        Proposal storage prop = proposals[proposalId];

        require(prop.id != 0, "proposal with a given id doesnt exist");
        require(statusDepositing(prop.status), "proposal is not depositing");
        require(msg.value > 0, "msg.value is zero");
        require(block.timestamp > prop.deadlines.depositingEndTime, "cannot deposit to an overdue proposal");

        prop.deposit = prop.deposit.add(msg.value);

        Depositor storage dep = depositors[msg.sender][prop.id];
        dep.depositedAmount = dep.depositedAmount + msg.value;
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

    function createSoftwareUpgradeProposal(string memory title, string memory description, string memory version) public {
        ensureProposalCanBeCreated(msg.sender);
        sopHandler.validateProposalRequest(version);
        createNewProposal(
            title,
            description,
            makeSUData(version),
            typeSoftwareUpgrade());
    }

    function createNewProposal(
        string memory title,
        string memory description,
        bytes memory proposalSpecialData,
        uint256 proposalType) internal
    {
        lastProposalId++;
        uint256 deposit = minimumDeposit(proposalType);
        require(msg.value >= minimumDeposit(proposalType), "starting deposit is less than required minimum deposit");

        Proposal memory prop;
        prop.id = lastProposalId;
        prop.title = title;
        prop.description = description;
        prop.deposit = deposit;
        prop.requiredDeposit = requiredDeposit(proposalType);
        prop.minVotesRequired = minVotesRequired(totalVotersNum(proposalType), proposalType);
        prop.proposalSpecialData = proposalSpecialData;
        prop.deadlines.depositingStartTime = block.timestamp;
        prop.deadlines.depositingEndTime = block.timestamp + depositingPeriod();
        prop.propType = proposalType;
        pushNewProposal(prop);

        emit ProposalIsCreated(prop.id);
    }

    function pushNewProposal(Proposal memory prop) internal {
        proposals[prop.id] = prop;
        uint256[] storage proposalIds = proposalsAtDeadline[prop.deadlines.depositingEndTime];
        proposalIds.push(prop.id);
        addNewDeadline(prop.deadlines.depositingEndTime);
    }

    function addNewDeadline(uint256 deadline) internal {
        deadlines.push(deadline);
        deadlineIdxs[deadline] = deadlines.length - 1;

        emit DeadlineAdded(deadline);
    }

    function resolveProposal(uint256 proposalId) internal {
        // todo: implement logic below
        Proposal storage prop = proposals[proposalId];
        if (prop.propType == typeSoftwareUpgrade()) {
            string memory version = string(prop.proposalSpecialData);
            sopHandler.resolveSoftwareUpgrade(version);
        }

        emit ResolvedProposal(proposalId);
    }

    function reduceVotersPower(uint256 proposalId, address voter, uint256 power) internal {
        uint256 choise = voters[voter][proposalId].choise;

        Proposal storage prop = proposals[proposalId];
        prop.choises[choise] -= power;
        voters[voter][proposalId].power -= power;
        reducedVotersPower[voter][proposalId] += power;
    }

    function increaseVotersPower(uint256 proposalId, address voter, uint256 power) internal {
        uint256 choise = voters[voter][proposalId].choise;

        Proposal storage prop = proposals[proposalId];
        prop.choises[choise] += power;
        voters[voter][proposalId].power += power;
        reducedVotersPower[voter][proposalId] -= power;
    }

    function proceedToVoting(uint256 proposalId) internal {
        Proposal storage prop = proposals[proposalId];
        prop.deadlines.votingStartTime = block.timestamp;
        prop.deadlines.votingEndTime = block.timestamp + votingPeriod();
        prop.status = setStatusVoting(prop.status);
    }

    function failProposal(uint256 proposalId) internal {
        Proposal storage prop = proposals[proposalId];
        prop.status = failStatus(prop.status);
        inactiveProposalIds.push(prop.id);
    }

    // creates special data for a software upgrade proposal
    function makeSUData(string memory version) internal pure returns (bytes memory) {
        return bytes(version);
    }
}