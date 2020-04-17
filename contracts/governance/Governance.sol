pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";


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

    Governable governableContract;

    mapping(uint256 => uint256) deadlineIdxs;
    // mapping(address => mapping(uint256 => uint256)) selfVotingPower;
    mapping(address => mapping(uint256 => bool)) delegationAllowed;
    mapping(address => mapping(uint256 => uint256)) delegatedVotingPower;
    mapping(address => mapping(uint256 => uint256)) delegationVotingPower;
    mapping(uint256 => uint256[]) proposalsAtDeadline;
    mapping(uint256 => Proposal) proposals;
    mapping(address => mapping(uint256 => address)) delegators; // delegation from address to another address at some proposalId
    mapping(address => mapping(uint256 => address[])) delegations; // delegation from address to another address at some proposalId\
    mapping(address => mapping(uint256 => uint256)) delegatorsIdxs; // delegators' indexes at the end of delegations map
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

    // temprorary commented out GC
    constructor(/*address _governableContract*/) public {
        // setGovernableContract(_governableContract);
    }

    function setGovernableContract(address _governableContract) public {
        require(msg.sender == ADMIN, "operation is not permitted");
        checkContractIsValid(_governableContract);

        governableContract = Governable(_governableContract);
    }

    // TODO: should this be a part of governableContract interface?
    function maxProposalsPerUser() public view returns (uint256) {
        return 1;
    }

    function accountVotingPower(address acc, uint256 proposalId) public view returns (uint256) {
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

        return 0;
    }

    function rejectDelegations(uint256 proposalId) public {
        require(delegationVotingPower[msg.sender][proposalId] == 0, "this address has already accepted delegation");
        delegationAllowed[msg.sender][proposalId] = false;
    }

    function allowDelegations(uint256 proposalId) public {
        require(canAcceptDelegations(msg.sender), "this address cannot accept delegations");
        delegationAllowed[msg.sender][proposalId] = true;
    }

    function getDelegatedVotingPower(uint256 proposalId, address voter) public returns(uint256) {
        address[] memory delegatedAddresses = delegations[msg.sender][proposalId];
        uint256 additionalVotingPower;
        for (uint256 i = 0; i<delegatedAddresses.length; i++) {
            additionalVotingPower = additionalVotingPower.add(accountVotingPower(voter, proposalId));
        }

        return additionalVotingPower;
    }

    function delegateVote(uint256 proposalId, address delegateTo) public {
        Proposal storage prop = proposals[proposalId];

        require(prop.id != 0, "proposal with a given id doesnt exist");
        require(delegateTo != msg.sender, "cannot delegate vote to oneself");
        require(delegators[msg.sender][proposalId] == address(0), "already delegated");
        require(delegationAllowed[delegateTo][proposalId], "address gave no permissions to accept delegations");
        require(delegations[msg.sender][proposalId].length == 0, "this address has already accepted delegations");

        uint256 ownVotingPower = accountVotingPower(msg.sender, prop.id);
        require(ownVotingPower != 0, "account has no votes to delegate");

        address[] storage delegs = delegations[delegateTo][prop.id];
        delegs.push(msg.sender);
        delegators[msg.sender][proposalId] = delegateTo;
        delegationVotingPower[delegateTo][proposalId] += ownVotingPower;
        delegatedVotingPower[msg.sender][proposalId] = ownVotingPower;
        delegatorsIdxs[msg.sender][proposalId] = delegs.length-1;
    }

    function cancelDelegation(uint256 proposalId) public {
        uint256 delegIdx = delegatorsIdxs[msg.sender][proposalId];

        // address[] storage delegators = delegations[delegatedTo][proposalId];
        address delegatedTo = delegators[msg.sender][proposalId];

        delete delegators[msg.sender][proposalId];
        delegationVotingPower[delegatedTo][proposalId] -= delegatedVotingPower[msg.sender][proposalId];
        delete delegatedVotingPower[msg.sender][proposalId];

        address[] storage delegs = delegations[delegatedTo][proposalId];
        delegs[delegIdx] = delegs[delegs.length - 1];
        address addrToShift = delegs[delegs.length - 1];
        delegatorsIdxs[addrToShift][proposalId] = delegIdx;
        delete delegatorsIdxs[msg.sender][proposalId];
        delegs.length--;
    }

    function vote(uint256 proposalId, uint256 choise) public {
        ensureAccountCanVote(msg.sender);

        Proposal storage prop = proposals[proposalId];

        require(voters[msg.sender][proposalId] == 0, "this account has already voted. try to cancel a vote if you want to revote");
        require(delegators[msg.sender][proposalId] == address(0), "this account has delegated a vote. try to cancel a delegation");
        require(prop.id == proposalId, "cannot find proposal with a passed id");
        require(statusVoting(prop.status), "cannot vote for a given proposal");

        uint256 delegPower = delegationVotingPower[msg.sender][proposalId];
        uint256 ownVotingPower = accountVotingPower(msg.sender, prop.id);
        prop.choises[choise] += ownVotingPower.add(delegPower);

        // TODO: check is choise possible!!!!
        // revert("could not find choise among proposal possible choises");
        voters[msg.sender][proposalId] = choise;
    }

    function cancelVote(uint256 proposalId) public {
        Proposal storage prop = proposals[proposalId];
        require(prop.votesCanBeCanceled, "votes cannot be canceled due to proposal settings");
        require(delegators[msg.sender][proposalId] == address(0), "sender has delegated his vote");

        uint256 delegatedVotingPower = getDelegatedVotingPower(proposalId, msg.sender);
        uint256 ownVotingPower = accountVotingPower(msg.sender, prop.id);
        uint256 prevChoise = voters[msg.sender][proposalId];
        prop.choises[prevChoise] -= ownVotingPower.add(delegatedVotingPower);

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
        // emit DeadlineAdded(deadlines[idx]);
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

    function increaseProposalDeposit(uint256 proposalId) public payable {
        Proposal storage prop = proposals[proposalId];

        require(prop.id != 0, "proposal with a given id doesnt exist");
        require(statusDepositing(prop.status), "proposal is not depositing");
        require(msg.value > 0, "msg.value is zero");
        require(block.timestamp > prop.deadlines.depositingEndTime, "cannot deposit to an overdue proposal");

        prop.deposit = prop.deposit.add(msg.value);
        depositors[prop.id][msg.sender] = depositors[prop.id][msg.sender].add(msg.value);
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

    function createSoftwareUpgradeProposal(string memory title, string memory description, string memory version) public {
        ensureProposalCanBeCreated(msg.sender);
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

    function resolveProposal(uint256 proposalId) internal {
        // todo: implement logic below
        emit ResolvedProposal(proposalId);
    }

    function ensureAccountCanVote(address addr) internal {
        if (addr == ADMIN) {
            return;
        }

        return;
    }

    function canAcceptDelegations(address addr) internal returns(bool) {
        // temprorary
        return false;
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

    function finalizeProposalVoting(uint256 proposalId) internal {
        
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

    function checkContractIsValid(address addr) internal {
        // address testAddr = address(0); // this.addr??

        require(isContract(addr), "address does not belong to a contract");
        // Todo: implement method check during SOProposal
        //for (uint i = 0; i<methodsOfGovernable.length; i++) {
        //    string memory method = methodsOfGovernable[i];
        //    bytes memory payload = abi.encodeWithSignature(method, testAddr);
        //    string memory errorMsg = string(abi.encodePacked(method, " is not implemented by contract"));
        //    (bool success, ) = addr.call(payload);
        //    require(success, errorMsg);
        //}
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}