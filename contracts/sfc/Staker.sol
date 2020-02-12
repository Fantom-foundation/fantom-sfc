pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "../ownership/Ownable.sol";

contract StakersConstants {
    using SafeMath for uint256;

    uint256 internal constant OK_STATUS = 0;
    uint256 internal constant FORK_BIT = 1;
    uint256 internal constant OFFLINE_BIT = 1 << 8;
    uint256 internal constant CHEATER_MASK = FORK_BIT;
    uint256 internal constant RATIO_UNIT = 1e6;

    function minStake() public pure returns (uint256) {
        return 3175000 * 1e18; // 3175000 FTM
    }

    function minStakeIncrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    function minDelegation() public pure returns (uint256) {
        return 1 * 1e18;
    }

    function minDelegationIncrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    function maxDelegatedRatio() public pure returns (uint256) {
        return 15 * RATIO_UNIT; // 1500%
    }

    function validatorCommission() public pure returns (uint256) {
        return (15 * RATIO_UNIT) / 100; // 15%
    }

    function contractCommission() public pure returns (uint256) {
        return (30 * RATIO_UNIT) / 100; // 30%
    }

    function stakeLockPeriodTime() public pure returns (uint256) {
        return 60 * 60 * 24 * 7; // 7 days
    }

    function stakeLockPeriodEpochs() public pure returns (uint256) {
        return 3;
    }

    function delegationLockPeriodTime() public pure returns (uint256) {
        return 60 * 60 * 24 * 7; // 7 days
    }

    function unbondingStartDate() public pure returns (uint256) {
        return 1577419000;
    }

    function bondedTargetPeriod() public pure returns (uint256) {
        return 60 * 60 * 24 * 700; // 100 weeks
    }

    function bondedTargetStart() public pure returns (uint256) {
        return (80 * RATIO_UNIT) / 100; // 80%
    }

    function unbondingUnlockPeriod() public pure returns (uint256) {
        return 60 * 60 * 24 * 30 * 6; // 6 months
    }

    function delegationLockPeriodEpochs() public pure returns (uint256) {
        return 3;
    }

    function maxStakerMetadataSize() public pure returns (uint256) {
        return 256;
    }

    event UpdatedBaseRewardPerSec(uint256 value);
    event UpdatedGasPowerAllocationRate(uint256 short, uint256 long);
}

contract Stakers is Ownable, StakersConstants {
    using SafeMath for uint256;

    struct Delegation {
        uint256 createdEpoch;
        uint256 createdTime;

        uint256 deactivatedEpoch;
        uint256 deactivatedTime;

        uint256 amount;
        uint256 paidUntilEpoch;
        uint256 toStakerID;
    }

    struct ValidationStake {
        uint256 status; // written by consensus outside

        uint256 createdEpoch;
        uint256 createdTime;
        uint256 deactivatedEpoch;
        uint256 deactivatedTime;

        uint256 stakeAmount;
        uint256 paidUntilEpoch;

        uint256 delegatedMe;

        address dagAddress;
        address sfcAddress;
    }

    struct ValidatorMerit {
        uint256 stakeAmount;
        uint256 delegatedMe;
        uint256 baseRewardWeight;
        uint256 txRewardWeight;
    }

    struct EpochSnapshot {
        mapping(uint256 => ValidatorMerit) validators; //  stakerID -> ValidatorMerit

        uint256 endTime;
        uint256 duration;
        uint256 epochFee;
        uint256 totalBaseRewardWeight;
        uint256 totalTxRewardWeight;
        uint256 baseRewardPerSecond;
        uint256 stakeTotalAmount;
        uint256 delegationsTotalAmount;
        uint256 totalSupply;
    }

    uint256 private reserved1;
    uint256 private reserved2;
    uint256 private reserved3;
    uint256 private reserved4;
    uint256 private reserved5;
    uint256 private reserved6;
    uint256 private reserved7;
    uint256 private reserved8;
    uint256 private reserved9;
    uint256 private reserved10;
    uint256 private reserved11;
    uint256 private reserved12;
    uint256 private reserved13;
    uint256 private reserved14;
    uint256 private reserved15;
    uint256 private reserved16;
    uint256 private reserved17;
    uint256 private reserved18;
    uint256 private reserved19;
    uint256 private reserved20;
    uint256 private reserved21;
    uint256 private reserved22;
    uint256 private reserved23;
    uint256 private reserved24;
    uint256 private reserved25;
    uint256 private reserved26;
    uint256 private reserved27;
    uint256 private reserved28;
    uint256 private reserved29;

    uint256 public currentSealedEpoch; // written by consensus outside
    mapping(uint256 => EpochSnapshot) public epochSnapshots; // written by consensus outside
    mapping(uint256 => ValidationStake) public stakers; // stakerID -> stake
    mapping(address => uint256) internal stakerIDs; // staker sfcAddress/dagAddress -> stakerID

    uint256 public stakersLastID;
    uint256 public stakersNum;
    uint256 public stakeTotalAmount;
    uint256 public delegationsNum;
    uint256 public delegationsTotalAmount;
    uint256 public slashedDelegationsTotalAmount;
    uint256 public slashedStakeTotalAmount;

    mapping(address => Delegation) public delegations; // delegationID -> delegation

    uint256 private deleted0;

    mapping(uint256 => bytes) public stakerMetadata;

    struct StashedRewards {
        uint256 amount;
    }

    mapping(address => StashedRewards) public rewardsStash; // addr -> StashedRewards

    struct WithdrawalRequest {
        uint256 stakerID;
        uint256 epoch;
        uint256 time;

        uint256 amount;

        bool delegation;
    }

    mapping(address => mapping(uint256 => WithdrawalRequest)) public withdrawalRequests;

    /*
    Getters
    */

    function epochValidator(uint256 e, uint256 v) external view returns (uint256 stakeAmount, uint256 delegatedMe, uint256 baseRewardWeight, uint256 txRewardWeight) {
        return (epochSnapshots[e].validators[v].stakeAmount,
                epochSnapshots[e].validators[v].delegatedMe,
                epochSnapshots[e].validators[v].baseRewardWeight,
                epochSnapshots[e].validators[v].txRewardWeight);
    }

    function currentEpoch() public view returns (uint256) {
        return currentSealedEpoch + 1;
    }

    // getStakerID by either dagAddress or sfcAddress
    function getStakerID(address addr) external view returns (uint256) {
        return stakerIDs[addr];
    }

    // Calculate bonded ratio
    function bondedRatio() public view returns(uint256) {
        uint256 totalSupply = epochSnapshots[currentSealedEpoch].totalSupply;
        if (totalSupply == 0) {
            return 0;
        }
        uint256 totalStaked = epochSnapshots[currentSealedEpoch].stakeTotalAmount.add(epochSnapshots[currentSealedEpoch].delegationsTotalAmount);
        return totalStaked.mul(RATIO_UNIT).div(totalSupply);
    }

    // Calculate bonded ratio target
    function bondedTargetRewardUnlock() public view returns (uint256) {
        uint256 passedTime = block.timestamp.sub(unbondingStartDate());
        uint256 passedPercents = RATIO_UNIT.mul(passedTime).div(bondedTargetPeriod()); // total duration from 0% to 100% is bondedTargetPeriod
        if (passedPercents >= bondedTargetStart()) {
            return 0;
        }
        return bondedTargetStart() - passedPercents;
    }

    // rewardsAllowed returns true if rewards are unlocked.
    // Rewards are unlocked when either 6 months passed or until TARGET% of the supply is staked,
    // where TARGET starts with 80% and decreases 1% every week
    function rewardsAllowed() public view returns (bool) {
        return block.timestamp >= unbondingStartDate() + unbondingUnlockPeriod() ||
               bondedRatio() >= bondedTargetRewardUnlock();
    }

    /*
    Methods
    */

    event CreatedStake(uint256 indexed stakerID, address indexed dagSfcAddress, uint256 amount);

    // Create new staker
    // Stake amount is msg.value
    // dagAdrress is msg.sender
    // sfcAdrress is msg.sender
    function createStake(bytes memory metadata) public payable {
        _createStake(msg.sender, msg.sender, msg.value, metadata);
    }

    // Create new staker
    // Stake amount is msg.value
    function createStakeWithAddresses(address dagAdrress, address sfcAddress, bytes memory metadata) public payable {
        require(dagAdrress != address(0), "invalid address");
        require(sfcAddress != address(0), "invalid address");
        _createStake(dagAdrress, sfcAddress, msg.value, metadata);
    }

    // Create new staker
    // Stake amount is msg.value
    function _createStake(address dagAdrress, address sfcAddress, uint256 amount, bytes memory metadata) internal {
        require(stakerIDs[dagAdrress] == 0, "staker already exists");
        require(stakerIDs[sfcAddress] == 0, "staker already exists");
        require(delegations[dagAdrress].amount == 0, "already delegating");
        require(delegations[sfcAddress].amount == 0, "already delegating");
        require(amount >= minStake(), "insufficient amount");

        uint256 stakerID = ++stakersLastID;
        stakerIDs[dagAdrress] = stakerID;
        stakerIDs[sfcAddress] = stakerID;
        stakers[stakerID].stakeAmount = amount;
        stakers[stakerID].createdEpoch = currentEpoch();
        stakers[stakerID].createdTime = block.timestamp;
        stakers[stakerID].dagAddress = dagAdrress;
        stakers[stakerID].sfcAddress = sfcAddress;
        stakers[stakerID].paidUntilEpoch = currentSealedEpoch;

        stakersNum++;
        stakeTotalAmount = stakeTotalAmount.add(amount);
        emit CreatedStake(stakerID, dagAdrress, amount);

        if (metadata.length != 0) {
            updateStakerMetadata(metadata);
        }

        if (dagAdrress != sfcAddress) {
            emit UpdatedStakerSfcAddress(stakerID, dagAdrress, sfcAddress);
        }
    }

    function _sfcAddressToStakerID(address sfcAddress) public view returns(uint256) {
        uint256 stakerID = stakerIDs[sfcAddress];
        if (stakerID == 0) {
            return 0;
        }
        if (stakers[stakerID].sfcAddress != sfcAddress) {
            return 0;
        }
        return stakerID;
    }

    event UpdatedStakerSfcAddress(uint256 indexed stakerID, address indexed oldSfcAddress, address indexed newSfcAddress);

    function updateStakerSfcAddress(address newSfcAddress) external {
        address oldSfcAddress = msg.sender;

        require(delegations[newSfcAddress].amount == 0, "already delegating");
        require(oldSfcAddress != newSfcAddress, "the same address");

        uint256 stakerID = _sfcAddressToStakerID(oldSfcAddress);
        require(stakerID != 0, "staker doesn't exist");
        require(stakerIDs[newSfcAddress] == 0 || stakerIDs[newSfcAddress] == stakerID, "address already used");

        // update address
        stakers[stakerID].sfcAddress = newSfcAddress;
        delete stakerIDs[oldSfcAddress];

        // update addresses index
        stakerIDs[newSfcAddress] = stakerID;
        stakerIDs[stakers[stakerID].dagAddress] = stakerID; // it's possible dagAddress == oldSfcAddress

        // redirect rewards stash
        if (rewardsStash[oldSfcAddress].amount != 0) {
            rewardsStash[newSfcAddress] = rewardsStash[oldSfcAddress];
            delete rewardsStash[oldSfcAddress];
        }

        emit UpdatedStakerSfcAddress(stakerID, oldSfcAddress, newSfcAddress);
    }

    event UpdatedStakerMetadata(uint256 indexed stakerID);

    function updateStakerMetadata(bytes memory metadata) public {
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        require(stakerID != 0, "staker doesn't exist");
        require(metadata.length <= maxStakerMetadataSize(), "too big metadata");
        stakerMetadata[stakerID] = metadata;

        emit UpdatedStakerMetadata(stakerID);
    }

    event IncreasedStake(uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    // Increase msg.sender's validator stake by msg.value
    function increaseStake() external payable {
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);

        require(msg.value >= minStakeIncrease(), "insufficient amount");
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker is deactivated");
        require(stakers[stakerID].status == OK_STATUS, "staker should be active");

        uint256 newAmount = stakers[stakerID].stakeAmount.add(msg.value);
        stakers[stakerID].stakeAmount = newAmount;
        stakeTotalAmount = stakeTotalAmount.add(msg.value);
        emit IncreasedStake(stakerID, newAmount, msg.value);
    }

    // maxDelegatedLimit is maximum amount of delegations to staker
    function maxDelegatedLimit(uint256 selfStake) internal pure returns (uint256) {
        return selfStake.mul(maxDelegatedRatio()).div(RATIO_UNIT);
    }

    event CreatedDelegation(address indexed delegator, uint256 indexed toStakerID, uint256 amount);

    // Create new delegation to a given staker
    // Delegated amount is msg.value
    function createDelegation(uint256 to) external payable {
        address delegator = msg.sender;

        require(stakers[to].stakeAmount != 0, "staker doesn't exist");
        require(stakers[to].status == OK_STATUS, "staker should be active");
        require(stakers[to].deactivatedTime == 0, "staker is deactivated");
        require(msg.value >= minDelegation(), "insufficient amount for delegation");
        require(delegations[delegator].amount == 0, "delegation already exists");
        require(stakerIDs[delegator] == 0, "already staking");
        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        newDelegation.paidUntilEpoch = currentSealedEpoch;
        delegations[delegator] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(delegator, to, msg.value);
    }

    event IncreasedDelegation(address indexed delegator, uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    // Increase msg.sender's delegation by msg.value
    function increaseDelegation() external payable {
        address delegator = msg.sender;

        require(delegations[delegator].amount != 0, "delegation doesn't exist");
        require(delegations[delegator].deactivatedTime == 0, "delegation is deactivated");
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        require(delegations[delegator].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed");

        uint256 to = delegations[delegator].toStakerID;

        require(msg.value >= minDelegationIncrease(), "insufficient amount");
        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");
        require(stakers[to].deactivatedTime == 0, "staker is deactivated");
        require(stakers[to].status == OK_STATUS, "staker should be active");

        uint256 newAmount = delegations[delegator].amount.add(msg.value);

        delegations[delegator].amount = newAmount;
        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit IncreasedDelegation(delegator, to, newAmount, msg.value);

        _syncDelegator(delegator);
        _syncStaker(to);
    }

    function _calcRawValidatorEpochReward(uint256 stakerID, uint256 epoch) view public returns (uint256) {
        uint256 totalBaseRewardWeight = epochSnapshots[epoch].totalBaseRewardWeight;
        uint256 baseRewardWeight = epochSnapshots[epoch].validators[stakerID].baseRewardWeight;
        uint256 totalTxRewardWeight = epochSnapshots[epoch].totalTxRewardWeight;
        uint256 txRewardWeight = epochSnapshots[epoch].validators[stakerID].txRewardWeight;

        // base reward
        uint256 baseReward = 0;
        if (baseRewardWeight != 0) {
            baseReward = epochSnapshots[epoch].duration.mul(epochSnapshots[epoch].baseRewardPerSecond).mul(baseRewardWeight).div(totalBaseRewardWeight);
        }
        // fee reward
        uint256 txReward = 0;
        if (txRewardWeight != 0) {
            txReward = epochSnapshots[epoch].epochFee.mul(txRewardWeight).div(totalTxRewardWeight);
            // fee reward except contractCommission
            txReward = txReward.mul(RATIO_UNIT - contractCommission()).div(RATIO_UNIT);
        }

        return baseReward.add(txReward);
    }

    function _calcValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 commission) view public returns (uint256) {
        uint256 rawReward = _calcRawValidatorEpochReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        if (totalStake == 0) {
            return 0; // avoid division by zero
        }
        uint256 weightedTotalStake = stake.add((delegatedTotal.mul(commission)).div(RATIO_UNIT));
        return (rawReward.mul(weightedTotalStake)).div(totalStake);
    }

    function _calcDelegationEpochReward(uint256 stakerID, uint256 epoch, uint256 delegationAmount, uint256 commission) view public returns (uint256) {
        uint256 rawReward = _calcRawValidatorEpochReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        if (totalStake == 0) {
            return 0; // avoid division by zero
        }
        uint256 weightedTotalStake = (delegationAmount.mul(RATIO_UNIT.sub(commission))).div(RATIO_UNIT);
        return (rawReward.mul(weightedTotalStake)).div(totalStake);
    }

    function withDefault(uint256 a, uint256 defaultA) pure private returns(uint256) {
        if (a == 0) {
            return defaultA;
        }
        return a;
    }

    // Returns the pending rewards for a given delegator, first calculated epoch, last calculated epoch
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function calcDelegationRewards(address delegator, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        uint256 stakerID = delegations[delegator].toStakerID;
        uint256 fromEpoch = withDefault(_fromEpoch, delegations[delegator].paidUntilEpoch + 1);
        assert(delegations[delegator].deactivatedTime == 0);

        if (delegations[delegator].paidUntilEpoch >= fromEpoch) {
            return (0, fromEpoch, 0);
        }

        uint256 pendingRewards = 0;
        uint256 lastEpoch = 0;
        for (uint256 e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            pendingRewards += _calcDelegationEpochReward(stakerID, e, delegations[delegator].amount, validatorCommission());
            lastEpoch = e;
        }
        return (pendingRewards, fromEpoch, lastEpoch);
    }

    // Returns the pending rewards for a given stakerID, first claimed epoch, last claimed epoch
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function calcValidatorRewards(uint256 stakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        uint256 fromEpoch = withDefault(_fromEpoch, stakers[stakerID].paidUntilEpoch + 1);

        if (stakers[stakerID].paidUntilEpoch >= fromEpoch) {
            return (0, fromEpoch, 0);
        }

        uint256 pendingRewards = 0;
        uint256 lastEpoch = 0;
        for (uint256 e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            pendingRewards += _calcValidatorEpochReward(stakerID, e, validatorCommission());
            lastEpoch = e;
        }
        return (pendingRewards, fromEpoch, lastEpoch);
    }

    // _claimRewards transfers rewards directly if rewards are allowed, or stashes them until rewards are unlocked
    function _claimRewards(address payable addr, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        if (rewardsAllowed()) {
            addr.transfer(amount);
        } else {
            rewardsStash[addr].amount += amount;
        }
    }

    event ClaimedDelegationReward(address indexed from, uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // Claim the pending rewards for a given delegator (sender)
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function claimDelegationRewards(uint256 maxEpochs) external {
        address payable delegator = msg.sender;

        require(delegations[delegator].amount != 0, "delegation doesn't exist");
        require(delegations[delegator].deactivatedTime == 0, "delegation is deactivated");
        (uint256 pendingRewards, uint256 fromEpoch, uint256 untilEpoch) = calcDelegationRewards(delegator, 0, maxEpochs);

        require(delegations[delegator].paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");

        delegations[delegator].paidUntilEpoch = untilEpoch;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        _claimRewards(delegator, pendingRewards);

        uint256 stakerID = delegations[delegator].toStakerID;
        emit ClaimedDelegationReward(delegator, stakerID, pendingRewards, fromEpoch, untilEpoch);
    }

    event ClaimedValidatorReward(uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // Claim the pending rewards for a given stakerID (sender)
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    //
    // may be already deactivated, but still allowed to withdraw old rewards
    function claimValidatorRewards(uint256 maxEpochs) external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);

        require(stakerID != 0, "staker doesn't exist");

        (uint256 pendingRewards, uint256 fromEpoch, uint256 untilEpoch) = calcValidatorRewards(stakerID, 0, maxEpochs);

        require(stakers[stakerID].paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");

        stakers[stakerID].paidUntilEpoch = untilEpoch;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        _claimRewards(stakerSfcAddr, pendingRewards);

        emit ClaimedValidatorReward(stakerID, pendingRewards, fromEpoch, untilEpoch);
    }

    event UnstashedRewards(address indexed auth, address indexed receiver, uint256 rewards);

    // Transfer the claimed rewards to account
    function unstashRewards() external {
        address auth = msg.sender;
        address payable receiver = msg.sender;
        uint256 rewards = rewardsStash[auth].amount;
        require(rewards != 0, "no rewards");
        require(rewardsAllowed(), "before minimum unlock period");

        delete rewardsStash[auth];

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        receiver.transfer(rewards);

        emit UnstashedRewards(auth, receiver, rewards);
    }

    event PreparedToWithdrawStake(uint256 indexed stakerID); // previous name for DeactivatedStake
    event DeactivatedStake(uint256 indexed stakerID);

    // deactivate stake, to be able to withdraw later
    function prepareToWithdrawStake() external {
        address stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker is deactivated");

        stakers[stakerID].deactivatedEpoch = currentEpoch();
        stakers[stakerID].deactivatedTime = block.timestamp;

        emit DeactivatedStake(stakerID);
    }

    event CreatedWithdrawRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, uint256 amount);

    function prepareToWithdrawStakePartial(uint256 wrID, uint256 amount) external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker is deactivated");
        require(amount != 0, "zero amount");

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 totalAmount = stakers[stakerID].stakeAmount;
        require(amount + minStake() <= totalAmount, "must leave at least minStake");
        uint256 newAmount = totalAmount - amount;
        require(maxDelegatedLimit(newAmount) >= stakers[stakerID].delegatedMe, "too much delegations");

        require(withdrawalRequests[stakerSfcAddr][wrID].amount == 0, "wrID already exists");

        stakers[stakerID].stakeAmount -= amount;
        withdrawalRequests[stakerSfcAddr][wrID].stakerID = stakerID;
        withdrawalRequests[stakerSfcAddr][wrID].amount = amount;
        withdrawalRequests[stakerSfcAddr][wrID].epoch = currentEpoch();
        withdrawalRequests[stakerSfcAddr][wrID].time = block.timestamp;

        emit CreatedWithdrawRequest(stakerSfcAddr, stakerSfcAddr, stakerID, wrID, amount);

        _syncStaker(stakerID);
    }

    event WithdrawnStake(uint256 indexed stakerID, uint256 penalty);

    function withdrawStake() external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        require(stakers[stakerID].deactivatedTime != 0, "staker wasn't deactivated");
        require(block.timestamp >= stakers[stakerID].deactivatedTime + stakeLockPeriodTime(), "not enough time passed");
        require(currentEpoch() >= stakers[stakerID].deactivatedEpoch + stakeLockPeriodEpochs(), "not enough epochs passed");

        address stakerDagAddr = stakers[stakerID].dagAddress;
        uint256 stake = stakers[stakerID].stakeAmount;
        uint256 penalty = 0;
        uint256 status = stakers[stakerID].status;
        bool isCheater = status & CHEATER_MASK != 0;
        delete stakers[stakerID];
        delete stakerMetadata[stakerID];
        delete stakerIDs[stakerSfcAddr];
        delete stakerIDs[stakerDagAddr];

        if (status != 0) {
            stakers[stakerID].status = status; // write status back into storage
        }
        stakersNum--;
        stakeTotalAmount = stakeTotalAmount.sub(stake);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            stakerSfcAddr.transfer(stake);
        } else {
            penalty = stake;
        }

        slashedStakeTotalAmount = slashedStakeTotalAmount.add(penalty);

        emit WithdrawnStake(stakerID, penalty);
    }

    event PreparedToWithdrawDelegation(address indexed delegator, uint256 indexed stakerID); // previous name for DeactivatedDelegation
    event DeactivatedDelegation(address indexed delegator, uint256 indexed stakerID);

    // deactivate delegation, to be able to withdraw later
    function prepareToWithdrawDelegation() external {
        address from = msg.sender;
        require(delegations[from].amount != 0, "delegation doesn't exist");
        require(delegations[from].deactivatedTime == 0, "delegation is deactivated");

        delegations[from].deactivatedEpoch = currentEpoch();
        delegations[from].deactivatedTime = block.timestamp;
        uint256 stakerID = delegations[from].toStakerID;
        uint256 delegationAmount = delegations[from].amount;

        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegationAmount);
        }

        emit DeactivatedDelegation(from, stakerID);
    }

    function prepareToWithdrawDelegationPartial(uint256 wrID, uint256 amount) external {
        address payable delegator = msg.sender;
        require(delegations[delegator].amount != 0, "delegation doesn't exist");
        require(delegations[delegator].deactivatedTime == 0, "delegation is deactivated");
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        require(delegations[delegator].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed");
        require(amount != 0, "zero amount");

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 stakerID = delegations[delegator].toStakerID;
        uint256 totalAmount = delegations[delegator].amount;
        require(amount + minDelegation() <= totalAmount, "must leave at least minDelegation");

        require(withdrawalRequests[delegator][wrID].amount == 0, "wrID already exists");

        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(amount);
        }


        delegations[delegator].amount -= amount;
        withdrawalRequests[delegator][wrID].stakerID = stakerID;
        withdrawalRequests[delegator][wrID].amount = amount;
        withdrawalRequests[delegator][wrID].epoch = currentEpoch();
        withdrawalRequests[delegator][wrID].time = block.timestamp;
        withdrawalRequests[delegator][wrID].delegation = true;

        emit CreatedWithdrawRequest(delegator, delegator, stakerID, wrID, amount);

        _syncDelegator(delegator);
        _syncStaker(stakerID);
    }

    event WithdrawnDelegation(address indexed delegator, uint256 indexed stakerID, uint256 penalty);

    function withdrawDelegation() external {
        address payable delegator = msg.sender;
        require(delegations[delegator].deactivatedTime != 0, "delegation wasn't deactivated");
        require(block.timestamp >= delegations[delegator].deactivatedTime + delegationLockPeriodTime(), "not enough time passed");
        require(currentEpoch() >= delegations[delegator].deactivatedEpoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        uint256 stakerID = delegations[delegator].toStakerID;
        uint256 penalty = 0;
        bool isCheater = stakers[stakerID].status & CHEATER_MASK != 0;
        uint256 delegationAmount = delegations[delegator].amount;
        delete delegations[delegator];

        delegationsNum--;
        delegationsTotalAmount = delegationsTotalAmount.sub(delegationAmount);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            delegator.transfer(delegationAmount);
        } else {
            penalty = delegationAmount;
        }

        slashedDelegationsTotalAmount = slashedDelegationsTotalAmount.add(penalty);

        emit WithdrawnDelegation(delegator, stakerID, penalty);
    }

    event WithdrawnByRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, uint256 penalty);

    function withdrawByRequest(uint256 wrID) external {
        address auth = msg.sender;
        address payable receiver = msg.sender;
        require(withdrawalRequests[auth][wrID].time != 0, "request doesn't exist");
        bool delegation = withdrawalRequests[auth][wrID].delegation;

        if (delegation) {
            require(block.timestamp >= withdrawalRequests[auth][wrID].time + delegationLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= withdrawalRequests[auth][wrID].epoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        } else {
            require(block.timestamp >= withdrawalRequests[auth][wrID].time + stakeLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= withdrawalRequests[auth][wrID].epoch + stakeLockPeriodEpochs(), "not enough epochs passed");
        }

        uint256 stakerID = withdrawalRequests[auth][wrID].stakerID;
        uint256 penalty = 0;
        bool isCheater = stakers[stakerID].status & CHEATER_MASK != 0;
        uint256 amount = withdrawalRequests[auth][wrID].amount;
        delete withdrawalRequests[auth][wrID];

        if (delegation) {
            delegationsTotalAmount = delegationsTotalAmount.sub(amount);
        } else {
            stakeTotalAmount = stakeTotalAmount.sub(amount);
        }

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            receiver.transfer(amount);
        } else {
            penalty = amount;
        }

        if (delegation) {
            slashedDelegationsTotalAmount = slashedDelegationsTotalAmount.add(penalty);
        } else {
            slashedStakeTotalAmount = slashedStakeTotalAmount.add(penalty);
        }

        emit WithdrawnByRequest(auth, receiver, stakerID, wrID, penalty);
    }

    function updateGasPowerAllocationRate(uint256 short, uint256 long) onlyOwner external {
        emit UpdatedGasPowerAllocationRate(short, long);
    }

    function updateBaseRewardPerSec(uint256 value) onlyOwner external {
        emit UpdatedBaseRewardPerSec(value);
    }

    event UpdatedDelegation(address indexed delegator, uint256 indexed oldStakerID, uint256 indexed newStakerID, uint256 amount);

    // syncDelegator updates the delegator data on node, if it differs for some reason
    function _syncDelegator(address delegator) public {
        require(delegations[delegator].amount != 0, "delegation doesn't exist");
        // emit special log for node
        emit UpdatedDelegation(delegator, delegations[delegator].toStakerID, delegations[delegator].toStakerID, delegations[delegator].amount);
    }

    event UpdatedStake(uint256 indexed stakerID, uint256 amount, uint256 delegatedMe);

    // syncStaker updates the staker data on node, if it differs for some reason
    function _syncStaker(uint256 stakerID) public {
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        // emit special log for node
        emit UpdatedStake(stakerID, stakers[stakerID].stakeAmount, stakers[stakerID].delegatedMe);
    }

    // _upgradeStakerStorage after stakerAddress is divided into sfcAddress and dagAddress
    function _upgradeStakerStorage(uint256 stakerID) external {
        require(stakers[stakerID].sfcAddress == address(0), "not updated");
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        stakers[stakerID].sfcAddress = stakers[stakerID].dagAddress;
    }
}

contract TestStakers is Stakers {
    function stakeLockPeriodTime() public pure returns (uint256) {
        return 1 * 60;
    }

    function delegationLockPeriodTime() public pure returns (uint256) {
        return 1 * 60;
    }
}

contract UnitTestStakers is Stakers {
    uint256[] public stakerIDsArr;

    function _baseRewardPerSecond() public pure returns (uint256) {
        return 0.0000000001 * 1e18;
    }

    function minStake() public pure returns (uint256) {
        return 1 * 1e18;
    }

    function minStakeIncrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    function minDelegation() public pure returns (uint256) {
        return 1 * 1e18;
    }

    constructor (uint256 firstEpoch) public {
        currentSealedEpoch = firstEpoch;
    }

    function _markValidationStakeAsCheater(uint256 stakerID, bool cheater) external {
        if (stakers[stakerID].stakeAmount != 0) {
            if (cheater) {
                stakers[stakerID].status = FORK_BIT;
            } else {
                stakers[stakerID].status = 0;
            }
        }
    }

    function _createStake() external payable {
        stakerIDsArr.push(stakersLastID + 1); // SS Check existing?
        super.createStake("");
    }

    function _makeEpochSnapshots(uint256 optionalDuration) external returns(uint256) {
        currentSealedEpoch++;
        EpochSnapshot storage newSnapshot = epochSnapshots[currentSealedEpoch];
        uint256 epochPay = 0;

        newSnapshot.endTime = block.timestamp;
        if (optionalDuration != 0 || currentSealedEpoch == 0) {
            newSnapshot.duration = optionalDuration;
        } else {
            newSnapshot.duration = block.timestamp - epochSnapshots[currentSealedEpoch - 1].endTime;
        }
        epochPay += newSnapshot.duration * _baseRewardPerSecond();

        for (uint256 i = 0; i < stakerIDsArr.length; i++) {
            uint256 deactivatedTime = stakers[stakerIDsArr[i]].deactivatedTime;
            if (deactivatedTime == 0 || block.timestamp < deactivatedTime) {
                uint256 basePower = stakers[stakerIDsArr[i]].stakeAmount + stakers[stakerIDsArr[i]].delegatedMe;
                uint256 txPower = 1000 * i + basePower;
                newSnapshot.totalBaseRewardWeight += basePower;
                newSnapshot.totalTxRewardWeight += txPower;
                newSnapshot.baseRewardPerSecond = _baseRewardPerSecond();
                newSnapshot.validators[stakerIDsArr[i]] = ValidatorMerit(
                    stakers[stakerIDsArr[i]].stakeAmount,
                    stakers[stakerIDsArr[i]].delegatedMe,
                    basePower,
                    txPower
                );
            }
        }

        newSnapshot.epochFee = 2 * 1e18;
        epochPay += newSnapshot.epochFee;

        return epochPay;
    }

    function rewardsAllowed() public view returns (bool) {
        return true;
    }
}
