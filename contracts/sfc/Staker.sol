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

        address stakerAddress;
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
    mapping(address => uint256) internal stakerIDs; // staker address -> stakerID

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

    event CreatedStake(uint256 indexed stakerID, address indexed stakerAddress, uint256 amount);

    // Create new staker
    // Stake amount is msg.value
    function createStake(bytes memory metadata) public payable {
        address staker = msg.sender;

        require(stakerIDs[staker] == 0, "staker already exists");
        require(delegations[staker].amount == 0, "already delegating");
        require(msg.value >= minStake(), "insufficient amount");

        uint256 stakerID = ++stakersLastID;
        stakerIDs[staker] = stakerID;
        stakers[stakerID].stakeAmount = msg.value;
        stakers[stakerID].createdEpoch = currentEpoch();
        stakers[stakerID].createdTime = block.timestamp;
        stakers[stakerID].stakerAddress = staker;
        stakers[stakerID].paidUntilEpoch = currentSealedEpoch;

        stakersNum++;
        stakeTotalAmount = stakeTotalAmount.add(msg.value);
        emit CreatedStake(stakerID, staker, msg.value);

        if (metadata.length != 0) {
            updateStakerMetadata(metadata);
        }
    }

    event UpdatedStakerMetadata(uint256 indexed stakerID);

    function updateStakerMetadata(bytes memory metadata) public {
        address staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];
        require(stakerID != 0, "staker doesn't exist");
        require(metadata.length <= maxStakerMetadataSize(), "too big metadata");
        stakerMetadata[stakerID] = metadata;

        emit UpdatedStakerMetadata(stakerID);
    }

    event IncreasedStake(uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    // Increase msg.sender's stake by msg.value
    function increaseStake() external payable {
        address staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];

        require(msg.value >= minStakeIncrease(), "insufficient amount");
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker is deactivated");
        require(stakers[stakerID].status == OK_STATUS, "staker should be active");

        uint256 newAmount = stakers[stakerID].stakeAmount.add(msg.value);
        stakers[stakerID].stakeAmount = newAmount;
        stakeTotalAmount = stakeTotalAmount.add(msg.value);
        emit IncreasedStake(stakerID, newAmount, msg.value);
    }

    event CreatedDelegation(address indexed from, uint256 indexed toStakerID, uint256 amount);

    // Create new delegation to a given staker
    // Delegated amount is msg.value
    function createDelegation(uint256 to) external payable {
        address from = msg.sender;

        require(stakers[to].stakeAmount != 0, "staker doesn't exist");
        require(stakers[to].status == OK_STATUS, "staker should be active");
        require(stakers[to].deactivatedTime == 0, "staker is deactivated");
        require(msg.value >= minDelegation(), "insufficient amount for delegation");
        require(delegations[from].amount == 0, "delegation already exists");
        require(stakerIDs[from] == 0, "already staking");
        require((stakers[to].stakeAmount.mul(maxDelegatedRatio())).div(RATIO_UNIT) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        newDelegation.paidUntilEpoch = currentSealedEpoch;
        delegations[from] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(from, to, msg.value);
    }

    function _calcTotalReward(uint256 stakerID, uint256 epoch) view public returns (uint256) {
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

    function _calcValidatorReward(uint256 stakerID, uint256 epoch) view public returns (uint256) {
        uint256 fullReward = _calcTotalReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        if (totalStake == 0) {
            return 0; // avoid division by zero
        }
        uint256 weightedTotalStake = stake.add((delegatedTotal.mul(validatorCommission())).div(RATIO_UNIT));
        return (fullReward.mul(weightedTotalStake)).div(totalStake);
    }

    function _calcDelegationReward(uint256 stakerID, uint256 epoch, uint256 delegatedAmount) view public returns (uint256) {
        uint256 fullReward = _calcTotalReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        if (totalStake == 0) {
            return 0; // avoid division by zero
        }
        uint256 weightedTotalStake = (delegatedAmount.mul(RATIO_UNIT.sub(validatorCommission()))).div(RATIO_UNIT);
        return (fullReward.mul(weightedTotalStake)).div(totalStake);
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
            pendingRewards += _calcDelegationReward(stakerID, e, delegations[delegator].amount);
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
            pendingRewards += _calcValidatorReward(stakerID, e);
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
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function claimDelegationRewards(uint256 _fromEpoch, uint256 maxEpochs) external {
        address payable delegator = msg.sender;

        require(delegations[delegator].amount != 0, "delegation doesn't exist");
        require(delegations[delegator].deactivatedTime == 0, "delegation is deactivated");
        (uint256 pendingRewards, uint256 fromEpoch, uint256 untilEpoch) = calcDelegationRewards(delegator, _fromEpoch, maxEpochs);

        require(delegations[delegator].paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");

        delegations[delegator].paidUntilEpoch = untilEpoch;
        _claimRewards(delegator, pendingRewards);

        uint256 stakerID = delegations[delegator].toStakerID;
        emit ClaimedDelegationReward(delegator, stakerID, pendingRewards, fromEpoch, untilEpoch);
    }

    event ClaimedValidatorReward(uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // Claim the pending rewards for a given stakerID (sender)
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    //
    // may be already deactivated, but still allowed to withdraw old rewards
    function claimValidatorRewards(uint256 _fromEpoch, uint256 maxEpochs) external {
        address payable staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];

        require(stakerID != 0, "staker doesn't exist");

        (uint256 pendingRewards, uint256 fromEpoch, uint256 untilEpoch) = calcValidatorRewards(stakerID, _fromEpoch, maxEpochs);

        require(stakers[stakerID].paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");

        stakers[stakerID].paidUntilEpoch = untilEpoch;
        _claimRewards(staker, pendingRewards);

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
        address staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker is deactivated");

        stakers[stakerID].deactivatedEpoch = currentEpoch();
        stakers[stakerID].deactivatedTime = block.timestamp;

        emit DeactivatedStake(stakerID);
    }

    event WithdrawnStake(uint256 indexed stakerID, uint256 penalty);

    function withdrawStake() external {
        address payable staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];
        require(stakers[stakerID].deactivatedTime != 0, "staker wasn't deactivated");
        require(block.timestamp >= stakers[stakerID].deactivatedTime + stakeLockPeriodTime(), "not enough time passed");
        require(currentEpoch() >= stakers[stakerID].deactivatedEpoch + stakeLockPeriodEpochs(), "not enough epochs passed");

        uint256 stake = stakers[stakerID].stakeAmount;
        uint256 penalty = 0;
        bool isCheater = stakers[stakerID].status & CHEATER_MASK != 0;
        delete stakers[stakerID];
        delete stakerMetadata[stakerID];
        delete stakerIDs[staker];

        stakersNum--;
        stakeTotalAmount = stakeTotalAmount.sub(stake);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            staker.transfer(stake);
        } else {
            penalty = stake;
        }

        slashedStakeTotalAmount = slashedStakeTotalAmount.add(penalty);

        emit WithdrawnStake(stakerID, penalty);
    }

    event PreparedToWithdrawDelegation(address indexed from, uint256 indexed stakerID); // previous name for DeactivatedDelegation
    event DeactivatedDelegation(address indexed from, uint256 indexed stakerID);

    // deactivate delegation, to be able to withdraw later
    function prepareToWithdrawDelegation() external {
        address from = msg.sender;
        require(delegations[from].amount != 0, "delegation doesn't exist");
        require(delegations[from].deactivatedTime == 0, "delegation is deactivated");

        delegations[from].deactivatedEpoch = currentEpoch();
        delegations[from].deactivatedTime = block.timestamp;
        uint256 stakerID = delegations[from].toStakerID;
        uint256 delegatedAmount = delegations[from].amount;
        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegatedAmount);
        }

        emit DeactivatedDelegation(from, stakerID);
    }

    event WithdrawnDelegation(address indexed from, uint256 indexed stakerID, uint256 penalty);

    function withdrawDelegation() external {
        address payable from = msg.sender;
        require(delegations[from].deactivatedTime != 0, "delegation wasn't deactivated");
        require(block.timestamp >= delegations[from].deactivatedTime + delegationLockPeriodTime(), "not enough time passed");
        require(currentEpoch() >= delegations[from].deactivatedEpoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        uint256 stakerID = delegations[from].toStakerID;
        uint256 penalty = 0;
        bool isCheater = stakers[stakerID].status & CHEATER_MASK != 0;
        uint256 delegatedAmount = delegations[from].amount;
        delete delegations[from];

        delegationsNum--;
        delegationsTotalAmount = delegationsTotalAmount.sub(delegatedAmount);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            from.transfer(delegatedAmount);
        } else {
            penalty = delegatedAmount;
        }

        slashedDelegationsTotalAmount = slashedDelegationsTotalAmount.add(penalty);

        emit WithdrawnDelegation(from, stakerID, penalty);
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
