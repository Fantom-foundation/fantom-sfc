pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./StakerConstants.sol";
import "../ownership/Ownable.sol";


/**
 * @dev Stakers contract defines data structure and methods for validators / stakers.
 */ 
contract Stakers is Ownable, StakersConstants {
    using SafeMath for uint256;

    /**
     * @dev A delegation
     */ 
    struct Delegation {
        uint256 createdEpoch;
        uint256 createdTime;

        uint256 deactivatedEpoch;
        uint256 deactivatedTime;

        uint256 amount;
        uint256 paidUntilEpoch;
        uint256 toStakerID;
    }

    /**
     * @dev The staking for validation
     */ 
    struct ValidationStake {
        uint256 status; // written by consensus outside

        uint256 createdEpoch;
        uint256 createdTime;
        uint256 deactivatedEpoch;
        uint256 deactivatedTime;

        uint256 stakeAmount;
        uint256 paidUntilEpoch;

        uint256 delegatedMe;

        address dagAddress; // address to authenticate validator's consensus messages (DAG events)
        address sfcAddress; // address to authenticate validator inside SFC contract
    }

    /**
     * @dev Validator's merit from own stake amount and delegated stake amounts
     */ 
    struct ValidatorMerit {
        uint256 stakeAmount;
        uint256 delegatedMe;
        uint256 baseRewardWeight;
        uint256 txRewardWeight;
    }

    /**
     * @dev A snapshot of an epoch
     */ 
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
        uint256 totalLockedAmount;
    }

    struct LockedAmount {
        uint256 fromEpoch;
        uint256 endTime;
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

    mapping(address => Delegation) public delegations; // DEPRECATED. delegationID -> delegation
    
    uint256 private deleted0;

    mapping(uint256 => bytes) public stakerMetadata;

    struct StashedRewards {
        uint256 amount;
    }

    mapping(address => mapping(uint256 => StashedRewards)) public rewardsStash; // addr, stashID -> StashedRewards

    struct WithdrawalRequest {
        uint256 stakerID;
        uint256 epoch;
        uint256 time;

        uint256 amount;

        bool delegation;
    }

    mapping(address => mapping(uint256 => WithdrawalRequest)) public withdrawalRequests;

    mapping(address => mapping(uint256 => Delegation)) public delegations_v2; // delegator address, staker ID -> delegations

    uint256 public firstLockedUpEpoch;
    mapping(uint256 => LockedAmount) public lockedStakes; // stakerID -> LockedAmount
    mapping(address => mapping(uint256 => LockedAmount)) public lockedDelegations; // delegator address, staker ID -> LockedAmount

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
        require(dagAdrress != address(0) || sfcAddress != address(0), "invalid address");
        _createStake(dagAdrress, sfcAddress, msg.value, metadata);
    }

    // Create new staker
    // Stake amount is msg.value
    function _createStake(address dagAdrress, address sfcAddress, uint256 amount, bytes memory metadata) internal {
        require(stakerIDs[dagAdrress] == 0 || stakerIDs[sfcAddress] == 0, "staker already exists");
//        require(delegations[dagAdrress].amount == 0, "already delegating"); // TODO: check it
//        require(delegations[sfcAddress].amount == 0, "already delegating");
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

    // update validator's SFC authentication/rewards/collateral address
    function updateStakerSfcAddress(address newSfcAddress) external {
        address oldSfcAddress = msg.sender;

       // require(delegations[newSfcAddress].amount == 0, "already delegating"); // <-- TODO: check it
        _checkAndUpgradeDelegateStorage(newSfcAddress);                          // <--
        _checkAndUpgradeDelegateStorage(oldSfcAddress);                          // <--
        require(oldSfcAddress != newSfcAddress, "the same address");

        uint256 stakerID = _sfcAddressToStakerID(oldSfcAddress);
        _checkExistStaker(stakerID);
        require(stakerIDs[newSfcAddress] == 0 || stakerIDs[newSfcAddress] == stakerID, "address already used");

        // update address
        stakers[stakerID].sfcAddress = newSfcAddress;
        delete stakerIDs[oldSfcAddress];

        // update addresses index
        stakerIDs[newSfcAddress] = stakerID;
        stakerIDs[stakers[stakerID].dagAddress] = stakerID; // it's possible dagAddress == oldSfcAddress

        // redirect rewards stash
        if (rewardsStash[oldSfcAddress][0].amount != 0) {
            rewardsStash[newSfcAddress][0] = rewardsStash[oldSfcAddress][0];
            delete rewardsStash[oldSfcAddress][0];
        }

        emit UpdatedStakerSfcAddress(stakerID, oldSfcAddress, newSfcAddress);
    }

    event UpdatedStakerMetadata(uint256 indexed stakerID);

    function updateStakerMetadata(bytes memory metadata) public {
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        _checkExistStaker(stakerID);
        require(metadata.length <= maxStakerMetadataSize(), "too big metadata");
        stakerMetadata[stakerID] = metadata;

        emit UpdatedStakerMetadata(stakerID);
    }

    event IncreasedStake(uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    // Increase msg.sender's validator stake by msg.value
    function increaseStake() external payable {
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);

        require(msg.value >= minStakeIncrease(), "insufficient amount");
        _checkActiveStaker(stakerID);

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
    function createDelegation(uint256 to) public payable {
        address delegator = msg.sender;

        _checkActiveStaker(to);
        require(msg.value >= minDelegation(), "insufficient amount");
        require(delegations_v2[delegator][to].amount == 0, "delegation already exists");
        require(stakerIDs[delegator] == 0, "already staking");

        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        newDelegation.paidUntilEpoch = currentSealedEpoch;
        delegations_v2[delegator][to] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(delegator, to, msg.value);
    }

    event IncreasedDelegation(address indexed delegator, uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    // Increase msg.sender's delegation by msg.value
    function increaseDelegation(uint256 to) external payable {
        address delegator = msg.sender;
        _checkAndUpgradeDelegateStorage(delegator);
        _checkActiveDelegation(delegator, to);
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        require(delegations_v2[delegator][to].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed");

        delegations_v2[delegator][to].toStakerID;

        require(msg.value >= minDelegationIncrease(), "insufficient amount");
        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");
        _checkActiveStaker(to);

        uint256 newAmount = delegations_v2[delegator][to].amount.add(msg.value);

        delegations_v2[delegator][to].amount = newAmount;
        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit IncreasedDelegation(delegator, to, newAmount, msg.value);

        _syncDelegator(delegator, to);
        _syncStaker(to);
    }

    function _calcRawValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 unlockedRatio) internal view returns (uint256) {
        uint256 totalBaseRewardWeight = epochSnapshots[epoch].totalBaseRewardWeight;
        uint256 baseRewardWeight = epochSnapshots[epoch].validators[stakerID].baseRewardWeight;
        uint256 totalTxRewardWeight = epochSnapshots[epoch].totalTxRewardWeight;
        uint256 txRewardWeight = epochSnapshots[epoch].validators[stakerID].txRewardWeight;

        // base reward
        uint256 baseReward = 0;
        if (baseRewardWeight != 0) {
            uint256 totalReward = epochSnapshots[epoch].duration.mul(epochSnapshots[epoch].baseRewardPerSecond);
            if (firstLockedUpEpoch > 0 && epoch >= firstLockedUpEpoch) {
                totalReward = totalReward.mul(unlockedRatio).div(RATIO_UNIT);
            }
            baseReward = totalReward.mul(baseRewardWeight).div(totalBaseRewardWeight);
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

    function _calcLockedUpReward(uint256 amount, uint256 epoch) internal view returns (uint256) {
        if (epochSnapshots[epoch].totalLockedAmount != 0) {
            uint256 totalReward = epochSnapshots[epoch].duration.mul(epochSnapshots[epoch].baseRewardPerSecond);
            return totalReward.mul(RATIO_UNIT - unlockedRatio()).div(RATIO_UNIT).mul(amount).div(epochSnapshots[epoch].totalLockedAmount);
        }
        return 0;
    }

    function _calcDelegationPenalty(address delegator, uint256 stakerID, uint256 withdrawalAmount) internal view returns (uint256) {
        uint256 penalty = 0;
        uint256 delegationAmount = delegations_v2[delegator][stakerID].amount;
        for (uint256 epoch = lockedDelegations[delegator][stakerID].fromEpoch; epoch <= currentSealedEpoch; ++epoch) {
            uint256 penaltyForEpoch = _calcDelegationEpochReward(delegator, stakerID, epoch, delegationAmount, validatorCommission(), unlockedRatio().div(2));
            penalty = penalty.add(penaltyForEpoch.mul(withdrawalAmount).div(delegationAmount));
        }
        return penalty;
    }

    function _calcValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 commission) internal view returns (uint256 validatorReward) {
        uint256 rawReward = _calcRawValidatorEpochReward(stakerID, epoch, unlockedRatio());

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        if (totalStake == 0) {
            return 0; // avoid division by zero
        }
        uint256 weightedTotalStake = stake.add((delegatedTotal.mul(commission)).div(RATIO_UNIT));

        validatorReward = rawReward.mul(weightedTotalStake).div(totalStake);
        if (firstLockedUpEpoch > 0 && epoch >= firstLockedUpEpoch) {
            if (lockedStakes[stakerID].fromEpoch <= epoch && lockedStakes[stakerID].endTime > epochSnapshots[epoch.sub(1)].endTime) {
                validatorReward = validatorReward.add(_calcLockedUpReward(stake, epoch));
            }
        }
        return validatorReward;
    }

    function _calcDelegationEpochReward(address delegator, uint256 stakerID, uint256 epoch, uint256 delegationAmount, uint256 commission, uint256 unlockedRatio) internal view returns (uint256 delegationReward) {
        uint256 rawReward = _calcRawValidatorEpochReward(stakerID, epoch, unlockedRatio);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        if (totalStake == 0) {
            return 0; // avoid division by zero
        }
        uint256 weightedTotalStake = (delegationAmount.mul(RATIO_UNIT.sub(commission))).div(RATIO_UNIT);
        delegationReward = rawReward.mul(weightedTotalStake).div(totalStake);
        if (firstLockedUpEpoch > 0 && epoch >= firstLockedUpEpoch) {
            if (lockedDelegations[delegator][stakerID].fromEpoch <= epoch && lockedDelegations[delegator][stakerID].endTime > epochSnapshots[epoch.sub(1)].endTime) {
                delegationReward = delegationReward.add(_calcLockedUpReward(delegationAmount, epoch));
            }
        }
        return delegationReward;
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
    function calcDelegationRewards(address delegator, uint256 stakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        require(delegations[delegator].amount == 0, "old version delegation, please update");
        Delegation memory delegation = delegations_v2[delegator][stakerID];
        uint256 fromEpoch = withDefault(_fromEpoch, delegation.paidUntilEpoch + 1);
        assert(delegation.deactivatedTime == 0);

        if (delegation.paidUntilEpoch >= fromEpoch) {
            return (0, fromEpoch, 0);
        }

        uint256 pendingRewards = 0;
        uint256 lastEpoch = 0;
        for (uint256 e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            pendingRewards += _calcDelegationEpochReward(delegator, stakerID, e, delegation.amount, validatorCommission(), unlockedRatio());
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
            rewardsStash[addr][0].amount = rewardsStash[addr][0].amount.add(amount);
        }
    }

    event ClaimedDelegationReward(address indexed from, uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // Claim the pending rewards for a given delegator (sender)
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function claimDelegationRewards(uint256 maxEpochs, uint256 stakerID) external {
        address payable delegator = msg.sender;
        _checkAndUpgradeDelegateStorage(delegator);
        _checkActiveDelegation(delegator, stakerID);
        (uint256 pendingRewards, uint256 fromEpoch, uint256 untilEpoch) = calcDelegationRewards(delegator, stakerID, 0, maxEpochs);

        _checkPaidEpoch(delegations_v2[delegator][stakerID].paidUntilEpoch, fromEpoch, untilEpoch);

        delegations_v2[delegator][stakerID].paidUntilEpoch = untilEpoch;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        _claimRewards(delegator, pendingRewards);

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
        _checkExistStaker(stakerID);

        (uint256 pendingRewards, uint256 fromEpoch, uint256 untilEpoch) = calcValidatorRewards(stakerID, 0, maxEpochs);
        _checkPaidEpoch(stakers[stakerID].paidUntilEpoch, fromEpoch, untilEpoch);

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
        uint256 rewards = rewardsStash[auth][0].amount;
        require(rewards != 0, "no rewards");
        require(rewardsAllowed(), "before minimum unlock period");

        delete rewardsStash[auth][0];

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        receiver.transfer(rewards);

        emit UnstashedRewards(auth, receiver, rewards);
    }

    // stashed rewards are burnt on deactivation in all the cases except when delegator has deactivated after
    // validator has deactivated or was slashed/pruned
    function _rewardsBurnableOnDeactivation(bool isDelegation, uint256 stakerID) public view returns(bool) {
        return !isDelegation || (stakers[stakerID].stakeAmount != 0 && stakers[stakerID].status == OK_STATUS && stakers[stakerID].deactivatedTime == 0);
    }

    event BurntRewardStash(address indexed addr, uint256 indexed stakerID, bool isDelegation, uint256 amount);

    // proportional part of stashed rewards are burnt on deactivation if _rewardsBurnableOnDeactivation returns true
    function _mayBurnRewardsOnDeactivation(bool isDelegation, uint256 stakerID, address addr, uint256 withdrawAmount, uint256 totalAmount) internal {
        if (_rewardsBurnableOnDeactivation(isDelegation, stakerID)) {
            uint256 leftAmount = totalAmount.sub(withdrawAmount);
            uint256 oldStash = rewardsStash[addr][0].amount;
            uint256 newStash = oldStash.mul(leftAmount).div(totalAmount);
            if (newStash == 0) {
                delete rewardsStash[addr][0];
            } else {
                rewardsStash[addr][0].amount = newStash;
            }
            if (newStash != oldStash) {
                emit BurntRewardStash(addr, stakerID, isDelegation, oldStash - newStash);
            }
        }
    }

    event PreparedToWithdrawStake(uint256 indexed stakerID); // previous name for DeactivatedStake
    event DeactivatedStake(uint256 indexed stakerID);

    // deactivate stake, to be able to withdraw later
    function prepareToWithdrawStake() external {
        address stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        _checkDeactivatedStaker(stakerID);
        require(stakers[stakerID].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed"); // for rewards burning
        require(lockedStakes[stakerID].fromEpoch == 0 || lockedStakes[stakerID].endTime < block.timestamp, "stake is locked");

        _mayBurnRewardsOnDeactivation(false, stakerID, stakerSfcAddr, stakers[stakerID].stakeAmount, stakers[stakerID].stakeAmount);

        stakers[stakerID].deactivatedEpoch = currentEpoch();
        stakers[stakerID].deactivatedTime = block.timestamp;

        emit DeactivatedStake(stakerID);
    }

    event CreatedWithdrawRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, bool delegation, uint256 amount);

    function prepareToWithdrawStakePartial(uint256 wrID, uint256 amount) external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        _checkDeactivatedStaker(stakerID);
        require(stakers[stakerID].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed"); // for rewards burning
        require(lockedStakes[stakerID].fromEpoch == 0 || lockedStakes[stakerID].endTime < block.timestamp, "stake is locked");
        require(amount >= minStakeDecrease(), "too small amount"); // avoid confusing wrID and amount

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 totalAmount = stakers[stakerID].stakeAmount;
        require(amount + minStake() <= totalAmount, "must leave at least minStake");
        uint256 newAmount = totalAmount - amount;
        require(maxDelegatedLimit(newAmount) >= stakers[stakerID].delegatedMe, "too much delegations");
        require(withdrawalRequests[stakerSfcAddr][wrID].amount == 0, "wrID already exists");

        _mayBurnRewardsOnDeactivation(false, stakerID, stakerSfcAddr, amount, totalAmount);

        stakers[stakerID].stakeAmount -= amount;
        withdrawalRequests[stakerSfcAddr][wrID].stakerID = stakerID;
        withdrawalRequests[stakerSfcAddr][wrID].amount = amount;
        withdrawalRequests[stakerSfcAddr][wrID].epoch = currentEpoch();
        withdrawalRequests[stakerSfcAddr][wrID].time = block.timestamp;

        emit CreatedWithdrawRequest(stakerSfcAddr, stakerSfcAddr, stakerID, wrID, false, amount);

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
    function prepareToWithdrawDelegation(uint256 stakerID) external {
        address delegator = msg.sender;
        _checkAndUpgradeDelegateStorage(delegator);
        _checkActiveDelegation(delegator, stakerID);
        Delegation storage delegation = delegations_v2[delegator][stakerID];
        require(delegation.paidUntilEpoch == currentSealedEpoch, "not all rewards claimed"); // for rewards burning

        _mayBurnRewardsOnDeactivation(true, stakerID, delegator, delegation.amount, delegation.amount);

        delegation.deactivatedEpoch = currentEpoch();
        delegation.deactivatedTime = block.timestamp;
        uint256 delegationAmount = delegation.amount;

        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegationAmount);
        }

        if (firstLockedUpEpoch > 0 && currentSealedEpoch >= firstLockedUpEpoch) {
            if (lockedDelegations[delegator][stakerID].endTime > block.timestamp) {
               uint256 penalty = _calcDelegationPenalty(delegator, stakerID, delegationAmount);
               if (penalty < delegationAmount) {
                   delegation.amount -= penalty;
                   delegationsTotalAmount -= penalty;
               } else {
                   delegationsTotalAmount -= delegationAmount;
                   delegation.amount = 0;
               }
            }
        }

        emit DeactivatedDelegation(delegator, stakerID);
    }

    function prepareToWithdrawDelegationPartial(uint256 wrID, uint256 stakerID, uint256 amount) external {
        address payable delegator = msg.sender;
        _checkAndUpgradeDelegateStorage(delegator);
        _checkActiveDelegation(delegator, stakerID);
        Delegation storage delegation = delegations_v2[delegator][stakerID];
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        require(delegation.paidUntilEpoch == currentSealedEpoch, "not all rewards claimed");
        require(amount >= minDelegationDecrease(), "too small amount"); // avoid confusing wrID and amount

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 totalAmount = delegation.amount;
        require(amount + minDelegation() <= totalAmount, "must leave at least minDelegation");

        require(withdrawalRequests[delegator][wrID].amount == 0, "wrID already exists");

        _mayBurnRewardsOnDeactivation(true, stakerID, delegator, amount, totalAmount);

        if (firstLockedUpEpoch > 0 && currentSealedEpoch >= firstLockedUpEpoch) {
            if (lockedDelegations[delegator][stakerID].endTime > block.timestamp) {
                uint256 penalty = _calcDelegationPenalty(delegator, stakerID, amount);
                delegation.amount -= amount;
                if (penalty < delegation.amount) {
                    delegation.amount -= penalty;
                    delegationsTotalAmount -= penalty;

                    if (stakers[stakerID].stakeAmount != 0) {
                        // if staker haven't withdrawn
                        stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(amount).sub(penalty);
                    }
                } else {
                    if (stakers[stakerID].stakeAmount != 0) {
                        // if staker haven't withdrawn
                        stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegation.amount);
                    }
                    delegation.deactivatedEpoch = currentEpoch();
                    delegation.deactivatedTime = block.timestamp;
                    emit DeactivatedDelegation(delegator, stakerID);

                    penalty -= delegation.amount;
                    if (penalty < amount) {
                        amount -= penalty;
                        delegationsTotalAmount -= penalty;
                    } else {
                        return ;
                    }
                }
            }
        }

        withdrawalRequests[delegator][wrID].stakerID = stakerID;
        withdrawalRequests[delegator][wrID].amount = amount;
        withdrawalRequests[delegator][wrID].epoch = currentEpoch();
        withdrawalRequests[delegator][wrID].time = block.timestamp;
        withdrawalRequests[delegator][wrID].delegation = true;

        emit CreatedWithdrawRequest(delegator, delegator, stakerID, wrID, true, amount);

        _syncDelegator(delegator, stakerID);
        _syncStaker(stakerID);
    }

    event WithdrawnDelegation(address indexed delegator, uint256 indexed stakerID, uint256 penalty);

    function withdrawDelegation(uint256 stakerID) external {
        address payable delegator = msg.sender;
        _checkAndUpgradeDelegateStorage(delegator);
        Delegation memory delegation = delegations_v2[delegator][stakerID];
        require(delegation.deactivatedTime != 0, "delegation wasn't deactivated");
        if (stakers[stakerID].stakeAmount != 0) {
            // if validator hasn't withdrawn already, then don't allow to withdraw delegation right away
            require(block.timestamp >= delegation.deactivatedTime + delegationLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= delegation.deactivatedEpoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        }
        uint256 penalty = 0;
        bool isCheater = stakers[stakerID].status & CHEATER_MASK != 0;
        uint256 delegationAmount = delegation.amount;
        delete delegations_v2[delegator][stakerID];
        delete lockedDelegations[delegator][stakerID];

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

    event PartialWithdrawnByRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, bool delegation, uint256 penalty);

    function partialWithdrawByRequest(uint256 wrID) external {
        address auth = msg.sender;
        address payable receiver = msg.sender;
        require(withdrawalRequests[auth][wrID].time != 0, "request doesn't exist");
        bool delegation = withdrawalRequests[auth][wrID].delegation;

        uint256 stakerID = withdrawalRequests[auth][wrID].stakerID;
        if (delegation && stakers[stakerID].stakeAmount != 0) {
            // if validator hasn't withdrawn already, then don't allow to withdraw delegation right away
            require(block.timestamp >= withdrawalRequests[auth][wrID].time + delegationLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= withdrawalRequests[auth][wrID].epoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        } else if (!delegation) {
            require(block.timestamp >= withdrawalRequests[auth][wrID].time + stakeLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= withdrawalRequests[auth][wrID].epoch + stakeLockPeriodEpochs(), "not enough epochs passed");
        }

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

        emit PartialWithdrawnByRequest(auth, receiver, stakerID, wrID, delegation, penalty);
    }

    function updateGasPowerAllocationRate(uint256 short, uint256 long) onlyOwner external {
        emit UpdatedGasPowerAllocationRate(short, long);
    }

    function updateBaseRewardPerSec(uint256 value) onlyOwner external {
        emit UpdatedBaseRewardPerSec(value);
    }

    function startLockedUp(uint256 epochNum) onlyOwner external {
        require(epochNum > currentSealedEpoch, "can't start in the past");
        require(firstLockedUpEpoch == 0 || firstLockedUpEpoch > currentSealedEpoch, "feature was started");
        firstLockedUpEpoch = epochNum;
    }

    event LockingStake(uint256 indexed stakerID, uint256 fromEpoch, uint256 endTime);

    function lockUpStake(uint256 lockDuration) external {
        require(firstLockedUpEpoch != 0 && firstLockedUpEpoch <= currentSealedEpoch.add(1), "feature was not activated");
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        _checkDeactivatedStaker(stakerID);
        require(lockDuration >= 86400 * 14 && lockDuration <= 86400 * 365, "incorrect duration");
        require(lockedStakes[stakerID].endTime < block.timestamp.add(lockDuration), "already locked up");
        uint256 endTime = block.timestamp.add(lockDuration);
        lockedStakes[stakerID] = LockedAmount(currentEpoch(), endTime);
        emit LockingStake(stakerID, currentEpoch(), endTime);
    }

    event LockingDelegation(address indexed delegator, uint256 indexed stakerID, uint256 fromEpoch, uint256 endTime);

    function lockUpDelegation(uint256 lockDuration, uint256 stakerID) external {
        require(firstLockedUpEpoch != 0 && firstLockedUpEpoch <= currentSealedEpoch.add(1), "feature was not activated");
        address delegator = msg.sender;
        _checkExistDelegation(delegator, stakerID);
        require(stakers[stakerID].status == OK_STATUS, "staker should be active");
        require(lockDuration >= 86400 * 14 && lockDuration <= 86400 * 365, "incorrect duration");
        uint256 endTime = block.timestamp.add(lockDuration);
        require(lockedStakes[stakerID].endTime >= endTime, "staker's locking will finish first");
        require(lockedDelegations[delegator][stakerID].endTime < endTime, "already locked up");
        lockedDelegations[delegator][stakerID] = LockedAmount(currentEpoch(), endTime);
        emit LockingDelegation(delegator, stakerID, currentEpoch(), endTime);
    }

    event UpdatedDelegation(address indexed delegator, uint256 indexed oldStakerID, uint256 indexed newStakerID, uint256 amount);

    // syncDelegator updates the delegator data on node, if it differs for some reason
    function _syncDelegator(address delegator, uint256 stakerID) public {
        _checkAndUpgradeDelegateStorage(delegator);
        _checkExistDelegation(delegator, stakerID);
        // emit special log for node
        emit UpdatedDelegation(delegator, stakerID, stakerID, delegations_v2[delegator][stakerID].amount);
    }

    event UpdatedStake(uint256 indexed stakerID, uint256 amount, uint256 delegatedMe);

    // syncStaker updates the staker data on node, if it differs for some reason
    function _syncStaker(uint256 stakerID) public {
        _checkExistStaker(stakerID);
        // emit special log for node
        emit UpdatedStake(stakerID, stakers[stakerID].stakeAmount, stakers[stakerID].delegatedMe);
    }

    // _upgradeStakerStorage after stakerAddress is divided into sfcAddress and dagAddress
    function _upgradeStakerStorage(uint256 stakerID) external {
        require(stakers[stakerID].sfcAddress == address(0), "not updated");
        _checkExistStaker(stakerID);
        stakers[stakerID].sfcAddress = stakers[stakerID].dagAddress;
    }

    function _checkExistStaker(uint256 to) view internal {
        require(stakers[to].stakeAmount != 0, "staker doesn't exist");
    }

    function _checkDeactivatedStaker(uint256 to) view internal {
        _checkExistStaker(to);
        require(stakers[to].deactivatedTime == 0, "staker is deactivated");
    }

    function _checkActiveStaker(uint256 to) view internal {
        _checkDeactivatedStaker(to);
        require(stakers[to].status == OK_STATUS, "staker should be active");
    }

    function _checkExistDelegation(address delegator, uint256 toStaker) view internal {
        require(delegations_v2[delegator][toStaker].amount != 0, "delegation doesn't exist");
    }

    function _checkActiveDelegation(address delegator, uint256 toStaker) view internal {
        _checkExistDelegation(delegator, toStaker);
        require(delegations_v2[delegator][toStaker].deactivatedTime == 0, "delegation is deactivated");
    }

    function _checkPaidEpoch(uint256 paidUntilEpoch, uint256 fromEpoch, uint256 untilEpoch) view internal {
        require(paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");
    }

    function _checkAndUpgradeDelegateStorage(address delegator) internal {
        if (delegations[delegator].amount != 0) {
            delegations_v2[delegator][delegations[delegator].toStakerID] = delegations[delegator];
            delete delegations[delegator];
        }
    }
}