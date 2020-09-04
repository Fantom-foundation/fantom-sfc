pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./StakerConstants.sol";
import "../ownership/Ownable.sol";
import "../version/Version.sol";

/**
 * @dev Stakers contract defines data structure and methods for validators / stakers.
 */
contract Stakers is Ownable, StakersConstants, Version {
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
    }

    struct LockedAmount {
        uint256 fromEpoch;
        uint256 endTime;
        uint256 duration;
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

    mapping(address => Delegation) public legacyDelegations; // delegator address -> delegation

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

    mapping(address => mapping(uint256 => Delegation)) public delegations; // delegator address, staker ID -> delegation

    uint256 public firstLockedUpEpoch;
    mapping(uint256 => LockedAmount) public lockedStakes; // stakerID -> LockedAmount
    mapping(address => mapping(uint256 => LockedAmount)) public lockedDelegations; // delegator address, staker ID -> LockedAmount
    mapping(address => mapping(uint256 => uint256)) public delegationEarlyWithdrawalPenalty; // delegator address, staker ID -> possible penalty for withdrawal

    uint256 public totalBurntLockupRewards;

    struct _RewardsSet {
        uint256 unlockedReward;
        uint256 lockupBaseReward;
        uint256 lockupExtraReward;
        uint256 burntReward;
    }

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

    /*
    Methods
    */

    event CreatedStake(uint256 indexed stakerID, address indexed dagSfcAddress, uint256 amount);

    // Create new staker
    // Stake amount is msg.value
    // dagAddress is msg.sender
    // sfcAdrress is msg.sender
    function createStake(bytes memory metadata) public payable {
        _createStake(msg.sender, msg.sender, msg.value, metadata);
    }

    // Create new staker
    // Stake amount is msg.value
    function createStakeWithAddresses(address dagAddress, address sfcAddress, bytes memory metadata) public payable {
        require(dagAddress != address(0) && sfcAddress != address(0), "invalid address");
        _createStake(dagAddress, sfcAddress, msg.value, metadata);
    }

    // Create new staker
    // Stake amount is msg.value
    function _createStake(address dagAddress, address sfcAddress, uint256 amount, bytes memory metadata) internal {
        require(stakerIDs[dagAddress] == 0 && stakerIDs[sfcAddress] == 0, "staker already exists");
        require(amount >= minStake(), "insufficient amount");

        uint256 stakerID = ++stakersLastID;
        stakerIDs[dagAddress] = stakerID;
        stakerIDs[sfcAddress] = stakerID;
        stakers[stakerID].stakeAmount = amount;
        stakers[stakerID].createdEpoch = currentEpoch();
        stakers[stakerID].createdTime = block.timestamp;
        stakers[stakerID].dagAddress = dagAddress;
        stakers[stakerID].sfcAddress = sfcAddress;
        stakers[stakerID].paidUntilEpoch = currentSealedEpoch;

        stakersNum++;
        stakeTotalAmount = stakeTotalAmount.add(amount);
        emit CreatedStake(stakerID, dagAddress, amount);

        if (metadata.length != 0) {
            updateStakerMetadata(metadata);
        }

        if (dagAddress != sfcAddress) {
            emit UpdatedStakerSfcAddress(stakerID, dagAddress, sfcAddress);
        }
    }

    function _sfcAddressToStakerID(address sfcAddress) public view returns (uint256) {
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

        require(oldSfcAddress != newSfcAddress, "the same address");

        uint256 stakerID = _sfcAddressToStakerID(oldSfcAddress);
        _checkExistStaker(stakerID);
        require(stakerIDs[newSfcAddress] == 0 || stakerIDs[newSfcAddress] == stakerID, "address already used");

        // update address
        stakers[stakerID].sfcAddress = newSfcAddress;
        delete stakerIDs[oldSfcAddress];

        // update addresses index
        stakerIDs[newSfcAddress] = stakerID;
        // it's possible dagAddress == oldSfcAddress
        stakerIDs[stakers[stakerID].dagAddress] = stakerID;

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

    function _createDelegation(address delegator, uint256 to) internal {
        _checkAndUpgradeDelegationStorage(delegator);
        _checkActiveStaker(to);
        require(msg.value >= minDelegation(), "insufficient amount");
        require(delegations[delegator][to].amount == 0, "delegation already exists");
        require(stakerIDs[delegator] == 0, "already staking");

        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        newDelegation.paidUntilEpoch = currentSealedEpoch;
        delegations[delegator][to] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(delegator, to, msg.value);
    }

    // Create new delegation to a given staker
    // Delegated amount is msg.value
    function createDelegation(uint256 to) external payable {
        _createDelegation(msg.sender, to);
    }

    event IncreasedDelegation(address indexed delegator, uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    // Increase msg.sender's delegation by msg.value
    function increaseDelegation(uint256 to) external payable {
        address delegator = msg.sender;
        _checkAndUpgradeDelegationStorage(delegator);
        _checkNotDeactivatedDelegation(delegator, to);
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        _checkClaimedDelegation(delegator, to);

        require(msg.value >= minDelegationIncrease(), "insufficient amount");
        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");
        _checkActiveStaker(to);

        uint256 newAmount = delegations[delegator][to].amount.add(msg.value);

        delegations[delegator][to].amount = newAmount;
        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit IncreasedDelegation(delegator, to, newAmount, msg.value);

        _syncDelegation(delegator, to);
        _syncStaker(to);
    }

    function _calcRawValidatorEpochReward(uint256 stakerID, uint256 epoch) internal view returns (uint256) {
        uint256 totalBaseRewardWeight = epochSnapshots[epoch].totalBaseRewardWeight;
        uint256 baseRewardWeight = epochSnapshots[epoch].validators[stakerID].baseRewardWeight;
        uint256 totalTxRewardWeight = epochSnapshots[epoch].totalTxRewardWeight;
        uint256 txRewardWeight = epochSnapshots[epoch].validators[stakerID].txRewardWeight;

        // base reward
        uint256 baseReward = 0;
        if (baseRewardWeight != 0) {
            uint256 totalReward = epochSnapshots[epoch].duration.mul(epochSnapshots[epoch].baseRewardPerSecond);
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

    function _calcDelegationPenalty(address delegator, uint256 toStakerID, uint256 withdrawalAmount, uint256 delegationAmount) internal view returns (uint256) {
        return delegationEarlyWithdrawalPenalty[delegator][toStakerID].mul(withdrawalAmount).div(delegationAmount);
    }

    function _calcLockupReward(uint256 fullReward, bool isLockingFeatureActive, bool isLockedUp) private pure returns (_RewardsSet memory rewards) {
        rewards = _RewardsSet(0, 0, 0, 0);
        if (isLockingFeatureActive) {
            if (isLockedUp) {
                rewards.unlockedReward = 0;
                rewards.lockupBaseReward = fullReward.mul(unlockedRewardRatio()).div(RATIO_UNIT);
                rewards.lockupExtraReward = fullReward - rewards.lockupBaseReward;
            } else {
                rewards.unlockedReward = fullReward.mul(unlockedRewardRatio()).div(RATIO_UNIT);
                rewards.lockupBaseReward = 0;
                rewards.lockupExtraReward = 0;
            }
        } else {
            rewards.unlockedReward = fullReward;
            rewards.lockupBaseReward = 0;
            rewards.lockupExtraReward = 0;
        }
        rewards.burntReward = fullReward - rewards.unlockedReward - rewards.lockupBaseReward - rewards.lockupExtraReward;
        return rewards;
    }

    function _calcValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 commission) internal view returns (_RewardsSet memory)  {
        uint256 fullReward = 0;
        {
            uint256 rawReward = _calcRawValidatorEpochReward(stakerID, epoch);

            uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
            uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
            uint256 totalStake = stake.add(delegatedTotal);
            if (totalStake == 0) {
                // avoid division by zero
                return _RewardsSet(0, 0, 0, 0);
            }
            uint256 weightedTotalStake = stake.add((delegatedTotal.mul(commission)).div(RATIO_UNIT));

            fullReward = rawReward.mul(weightedTotalStake).div(totalStake);
        }
        bool isLockingFeatureActive = firstLockedUpEpoch > 0 && epoch >= firstLockedUpEpoch;
        bool isLockedUp = lockedStakes[stakerID].fromEpoch <= epoch && lockedStakes[stakerID].endTime > epochStartTime(epoch);

        return _calcLockupReward(fullReward, isLockingFeatureActive, isLockedUp);
    }

    function _calcDelegationEpochReward(address delegator, uint256 toStakerID, uint256 epoch, uint256 commission) internal view returns (_RewardsSet memory) {
        uint256 fullReward = 0;
        {
            uint256 rawReward = _calcRawValidatorEpochReward(toStakerID, epoch);

            uint256 stake = epochSnapshots[epoch].validators[toStakerID].stakeAmount;
            uint256 delegatedTotal = epochSnapshots[epoch].validators[toStakerID].delegatedMe;
            uint256 totalStake = stake.add(delegatedTotal);
            if (totalStake == 0) {
                // avoid division by zero
                return _RewardsSet(0, 0, 0, 0);
            }
            uint256 delegationAmount = delegations[delegator][toStakerID].amount;
            uint256 weightedTotalStake = (delegationAmount.mul(RATIO_UNIT.sub(commission))).div(RATIO_UNIT);

            fullReward = rawReward.mul(weightedTotalStake).div(totalStake);
        }
        bool isLockingFeatureActive = firstLockedUpEpoch > 0 && epoch >= firstLockedUpEpoch;
        bool isLockedUp = lockedDelegations[delegator][toStakerID].fromEpoch <= epoch && lockedDelegations[delegator][toStakerID].endTime > epochStartTime(epoch);

        return _calcLockupReward(fullReward, isLockingFeatureActive, isLockedUp);
    }

    function withDefault(uint256 a, uint256 defaultA) pure private returns (uint256) {
        if (a == 0) {
            return defaultA;
        }
        return a;
    }

    function _calcDelegationLockupRewards(address delegator, uint256 toStakerID, uint256 fromEpoch, uint256 maxEpochs) internal view returns (_RewardsSet memory, uint256, uint256) {
        Delegation memory delegation = delegations[delegator][toStakerID];
        fromEpoch = withDefault(fromEpoch, delegation.paidUntilEpoch + 1);
        assert(delegation.deactivatedTime == 0);

        if (delegation.paidUntilEpoch >= fromEpoch) {
            return (_RewardsSet(0, 0, 0, 0), fromEpoch, 0);
        }

        _RewardsSet memory rewards = _RewardsSet(0, 0, 0, 0);

        uint256 e;
        for (e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            _RewardsSet memory eRewards = _calcDelegationEpochReward(delegator, toStakerID, e, validatorCommission());
            rewards.unlockedReward += eRewards.unlockedReward;
            rewards.lockupBaseReward += eRewards.lockupBaseReward;
            rewards.lockupExtraReward += eRewards.lockupExtraReward;
            rewards.burntReward += eRewards.burntReward;
        }
        uint256 lastEpoch;
        if (e <= fromEpoch) {
            lastEpoch = 0;
        } else {
            lastEpoch = e - 1;
        }
        return (rewards, fromEpoch, lastEpoch);
    }

    // Returns the pending rewards for a given delegator, first calculated epoch, last calculated epoch
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function calcDelegationRewards(address delegator, uint256 toStakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcDelegationLockupRewards(delegator, toStakerID, _fromEpoch, maxEpochs);
        return (rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward, fromEpoch, untilEpoch);
    }

    function _calcValidatorLockupRewards(uint256 stakerID, uint256 fromEpoch, uint256 maxEpochs) internal view returns (_RewardsSet memory, uint256, uint256) {
        fromEpoch = withDefault(fromEpoch, stakers[stakerID].paidUntilEpoch + 1);

        if (stakers[stakerID].paidUntilEpoch >= fromEpoch) {
            return (_RewardsSet(0, 0, 0, 0), fromEpoch, 0);
        }

        _RewardsSet memory rewards = _RewardsSet(0, 0, 0, 0);

        uint256 e;
        for (e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            _RewardsSet memory eRewards = _calcValidatorEpochReward(stakerID, e, validatorCommission());
            rewards.unlockedReward += eRewards.unlockedReward;
            rewards.lockupBaseReward += eRewards.lockupBaseReward;
            rewards.lockupExtraReward += eRewards.lockupExtraReward;
            rewards.burntReward += eRewards.burntReward;
        }
        uint256 lastEpoch;
        if (e <= fromEpoch) {
            lastEpoch = 0;
        } else {
            lastEpoch = e - 1;
        }
        return (rewards, fromEpoch, lastEpoch);
    }

    // Returns the pending rewards for a given stakerID, first claimed epoch, last claimed epoch
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function calcValidatorRewards(uint256 stakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcValidatorLockupRewards(stakerID, _fromEpoch, maxEpochs);
        return (rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward, fromEpoch, untilEpoch);
    }

    event ClaimedDelegationReward(address indexed from, uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // Claim the pending rewards for a given delegator (sender)
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function claimDelegationRewards(uint256 maxEpochs, uint256 toStakerID) external {
        address payable delegator = msg.sender;
        _checkAndUpgradeDelegationStorage(delegator);
        Delegation storage delegation = delegations[delegator][toStakerID];
        _checkNotDeactivatedDelegation(delegator, toStakerID);
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcDelegationLockupRewards(delegator, toStakerID, 0, maxEpochs);

        uint256 rewardsAll = rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
        _checkPaidEpoch(delegation.paidUntilEpoch, fromEpoch, untilEpoch);

        delegation.paidUntilEpoch = untilEpoch;
        delegationEarlyWithdrawalPenalty[delegator][toStakerID] += rewards.lockupBaseReward / 2 + rewards.lockupExtraReward;
        totalBurntLockupRewards += rewards.burntReward;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        delegator.transfer(rewardsAll);

        emit ClaimedDelegationReward(delegator, toStakerID, rewardsAll, fromEpoch, untilEpoch);
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

        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcValidatorLockupRewards(stakerID, 0, maxEpochs);

        uint256 rewardsAll = rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
        _checkPaidEpoch(stakers[stakerID].paidUntilEpoch, fromEpoch, untilEpoch);

        stakers[stakerID].paidUntilEpoch = untilEpoch;
        totalBurntLockupRewards += rewards.burntReward;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        stakerSfcAddr.transfer(rewardsAll);

        emit ClaimedValidatorReward(stakerID, rewardsAll, fromEpoch, untilEpoch);
    }

    event UnstashedRewards(address indexed auth, address indexed receiver, uint256 rewards);

    // Transfer the claimed rewards to account
    function unstashRewards() external {
        address auth = msg.sender;
        address payable receiver = msg.sender;
        uint256 rewards = rewardsStash[auth][0].amount;
        require(rewards != 0, "no rewards");

        delete rewardsStash[auth][0];

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        receiver.transfer(rewards);

        emit UnstashedRewards(auth, receiver, rewards);
    }

    // stashed rewards are burnt on deactivation in all the cases except when delegator has deactivated after
    // validator has deactivated or was slashed/pruned
    function _rewardsBurnableOnDeactivation(bool isDelegation, uint256 stakerID) public view returns (bool) {
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
        _checkNotDeactivatedStaker(stakerID);
        _checkClaimedStaker(stakerID);
        require(!_isLockedStake(stakerID), "stake is locked");

        _mayBurnRewardsOnDeactivation(false, stakerID, stakerSfcAddr, stakers[stakerID].stakeAmount, stakers[stakerID].stakeAmount);

        stakers[stakerID].deactivatedEpoch = currentEpoch();
        stakers[stakerID].deactivatedTime = block.timestamp;

        emit DeactivatedStake(stakerID);
    }

    event CreatedWithdrawRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, bool delegation, uint256 amount);

    function prepareToWithdrawStakePartial(uint256 wrID, uint256 amount) external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        _checkNotDeactivatedStaker(stakerID);
        _checkClaimedStaker(stakerID);
        require(!_isLockedStake(stakerID), "stake is locked");
        // avoid confusing wrID and amount
        require(amount >= minStakeDecrease(), "too small amount");

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
            // write status back into storage
            stakers[stakerID].status = status;
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
    function prepareToWithdrawDelegation(uint256 toStakerID) external {
        address delegator = msg.sender;
        _checkAndUpgradeDelegationStorage(delegator);
        Delegation storage delegation = delegations[delegator][toStakerID];
        _checkNotDeactivatedDelegation(delegator, toStakerID);
        _checkClaimedDelegation(delegator, toStakerID);

        _mayBurnRewardsOnDeactivation(true, toStakerID, delegator, delegation.amount, delegation.amount);

        delegation.deactivatedEpoch = currentEpoch();
        delegation.deactivatedTime = block.timestamp;
        uint256 delegationAmount = delegation.amount;

        if (stakers[toStakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[toStakerID].delegatedMe = stakers[toStakerID].delegatedMe.sub(delegationAmount);
        }

        uint256 penalty = 0;
        if (_isLockedDelegation(delegator, toStakerID)) {
            penalty = _calcDelegationPenalty(delegator, toStakerID, delegationAmount, delegationAmount);
            if (penalty >= delegationAmount) {
                penalty = delegationAmount - 1;
            }
            // forgive penalty
            delegationEarlyWithdrawalPenalty[delegator][toStakerID] -= penalty;
        }
        // delegator will receive less funds on withdrawal if penalty > 0
        delegation.amount -= penalty;
        delegationsTotalAmount -= penalty;

        emit DeactivatedDelegation(delegator, toStakerID);

        _syncDelegation(delegator, toStakerID);
        _syncStaker(toStakerID);
    }

    function prepareToWithdrawDelegationPartial(uint256 wrID, uint256 toStakerID, uint256 amount) external {
        address payable delegator = msg.sender;
        _checkAndUpgradeDelegationStorage(delegator);
        Delegation storage delegation = delegations[delegator][toStakerID];
        _checkNotDeactivatedDelegation(delegator, toStakerID);
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        _checkClaimedDelegation(delegator, toStakerID);
        // avoid confusing wrID and amount
        require(amount >= minDelegationDecrease(), "too small amount");

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 totalAmount = delegation.amount;
        require(amount + minDelegation() <= totalAmount, "must leave at least minDelegation");

        require(withdrawalRequests[delegator][wrID].amount == 0, "wrID already exists");

        _mayBurnRewardsOnDeactivation(true, toStakerID, delegator, amount, totalAmount);

        uint256 penalty = 0;
        if (_isLockedDelegation(delegator, toStakerID)) {
            penalty = _calcDelegationPenalty(delegator, toStakerID, amount, totalAmount);
            if (penalty >= amount) {
                penalty = amount - 1;
            }
            // forgive penalty
            delegationEarlyWithdrawalPenalty[delegator][toStakerID] -= penalty;
        }
        delegation.amount -= amount;
        if (stakers[toStakerID].stakeAmount != 0) {
            // if staker hasn't withdrawn
            stakers[toStakerID].delegatedMe = stakers[toStakerID].delegatedMe.sub(amount);
        }

        withdrawalRequests[delegator][wrID].stakerID = toStakerID;
        // delegator will receive less funds on withdrawal if penalty > 0
        withdrawalRequests[delegator][wrID].amount = amount - penalty;
        withdrawalRequests[delegator][wrID].epoch = currentEpoch();
        withdrawalRequests[delegator][wrID].time = block.timestamp;
        withdrawalRequests[delegator][wrID].delegation = true;

        emit CreatedWithdrawRequest(delegator, delegator, toStakerID, wrID, true, amount);

        _syncDelegation(delegator, toStakerID);
        _syncStaker(toStakerID);
    }

    event WithdrawnDelegation(address indexed delegator, uint256 indexed toStakerID, uint256 penalty);

    function withdrawDelegation(uint256 toStakerID) external {
        address payable delegator = msg.sender;
        _checkAndUpgradeDelegationStorage(delegator);
        Delegation memory delegation = delegations[delegator][toStakerID];
        require(delegation.deactivatedTime != 0, "delegation wasn't deactivated");
        if (stakers[toStakerID].stakeAmount != 0) {
            // if validator hasn't withdrawn already, then don't allow to withdraw delegation right away
            require(block.timestamp >= delegation.deactivatedTime + delegationLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= delegation.deactivatedEpoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        }
        uint256 penalty = 0;
        bool isCheater = stakers[toStakerID].status & CHEATER_MASK != 0;
        uint256 delegationAmount = delegation.amount;
        delete delegations[delegator][toStakerID];
        delete lockedDelegations[delegator][toStakerID];
        delete delegationEarlyWithdrawalPenalty[delegator][toStakerID];

        delegationsNum--;

        delegationsTotalAmount = delegationsTotalAmount.sub(delegationAmount);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            delegator.transfer(delegationAmount);
        } else {
            penalty = delegationAmount;
        }

        slashedDelegationsTotalAmount = slashedDelegationsTotalAmount.add(penalty);

        emit WithdrawnDelegation(delegator, toStakerID, penalty);
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

    function _updateGasPowerAllocationRate(uint256 short, uint256 long) onlyOwner external {
        emit UpdatedGasPowerAllocationRate(short, long);
    }

    function _updateBaseRewardPerSec(uint256 value) onlyOwner external {
        emit UpdatedBaseRewardPerSec(value);
    }

    function _updateOfflinePenaltyThreshold(uint256 blocksNum, uint256 period) onlyOwner external {
        emit UpdatedOfflinePenaltyThreshold(blocksNum, period);
    }

    function startLockedUp(uint256 epochNum) onlyOwner external {
        require(epochNum > currentSealedEpoch, "can't start in the past");
        require(firstLockedUpEpoch == 0 || firstLockedUpEpoch > currentSealedEpoch, "feature was started");
        firstLockedUpEpoch = epochNum;
    }

    event LockingStake(uint256 indexed stakerID, uint256 fromEpoch, uint256 endTime);

    function lockUpStake(uint256 lockDuration) external {
        require(firstLockedUpEpoch != 0 && firstLockedUpEpoch <= currentSealedEpoch + 1, "feature was not activated");
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        _checkActiveStaker(stakerID);
        require(lockDuration >= minLockupDuration() && lockDuration <= maxLockupDuration(), "incorrect duration");
        uint256 endTime = block.timestamp.add(lockDuration);
        require(!_isLockedStake(stakerID), "already locked up");
        _checkClaimedStakerLockupRewards(stakerID);

        lockedStakes[stakerID] = LockedAmount(currentEpoch(), endTime, lockDuration);
        emit LockingStake(stakerID, currentEpoch(), endTime);
    }

    event LockingDelegation(address indexed delegator, uint256 indexed stakerID, uint256 fromEpoch, uint256 endTime);

    function lockUpDelegation(uint256 lockDuration, uint256 toStakerID) external {
        require(firstLockedUpEpoch != 0 && firstLockedUpEpoch <= currentSealedEpoch + 1, "feature was not activated");
        address delegator = msg.sender;
        _checkAndUpgradeDelegationStorage(delegator);
        _checkExistDelegation(delegator, toStakerID);
        _checkActiveStaker(toStakerID);
        require(lockDuration >= minLockupDuration() && lockDuration <= maxLockupDuration(), "incorrect duration");
        uint256 endTime = block.timestamp.add(lockDuration);
        require(lockedStakes[toStakerID].endTime >= endTime, "staker's locking will finish first");
        require(!_isLockedDelegation(delegator, toStakerID), "already locked up");
        _checkClaimedDelegationLockupRewards(delegator, toStakerID);

        {
            // forgive non-paid penalty from previous lockup period, if any
            delete delegationEarlyWithdrawalPenalty[delegator][toStakerID];
        }
        lockedDelegations[delegator][toStakerID] = LockedAmount(currentEpoch(), endTime, lockDuration);
        emit LockingDelegation(delegator, toStakerID, currentEpoch(), endTime);
    }

    event UpdatedDelegation(address indexed delegator, uint256 indexed oldStakerID, uint256 indexed newStakerID, uint256 amount);

    // syncDelegator updates the delegator data on node, if it differs for some reason
    function _syncDelegation(address delegator, uint256 toStakerID) public {
        _checkExistDelegation(delegator, toStakerID);
        // emit special log for node
        emit UpdatedDelegation(delegator, toStakerID, toStakerID, delegations[delegator][toStakerID].amount);
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
        require(stakers[stakerID].sfcAddress == address(0), "already updated");
        _checkExistStaker(stakerID);
        stakers[stakerID].sfcAddress = stakers[stakerID].dagAddress;
    }

    function _checkExistStaker(uint256 to) view internal {
        require(stakers[to].stakeAmount != 0, "staker doesn't exist");
    }

    function _checkNotDeactivatedStaker(uint256 to) view internal {
        _checkExistStaker(to);
        require(stakers[to].deactivatedTime == 0, "staker is deactivated");
    }

    function _checkActiveStaker(uint256 to) view internal {
        _checkNotDeactivatedStaker(to);
        require(stakers[to].status == OK_STATUS, "staker should be active");
    }

    function _checkExistDelegation(address delegator, uint256 toStakerID) view internal {
        require(delegations[delegator][toStakerID].amount != 0, "delegation doesn't exist");
    }

    function _checkNotDeactivatedDelegation(address delegator, uint256 toStakerID) view internal {
        _checkExistDelegation(delegator, toStakerID);
        require(delegations[delegator][toStakerID].deactivatedTime == 0, "delegation is deactivated");
    }

    function _checkClaimedStaker(uint256 stakerID) view internal {
        require(stakers[stakerID].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed");
    }

    function _checkClaimedDelegation(address delegator, uint256 toStakerID) view internal {
        require(delegations[delegator][toStakerID].paidUntilEpoch == currentSealedEpoch, "not all rewards claimed");
    }

    function epochStartTime(uint256 epoch) view internal returns (uint256) {
        return epochSnapshots[epoch - 1].endTime;
    }

    function _checkClaimedDelegationLockupRewards(address delegator, uint256 toStakerID) view internal {
        uint256 claimedEpoch = delegations[delegator][toStakerID].paidUntilEpoch;
        require(epochStartTime(claimedEpoch + 1) >= lockedDelegations[delegator][toStakerID].endTime, "not all lockup rewards claimed");
    }

    function _checkClaimedStakerLockupRewards(uint256 stakerID) view internal {
        uint256 claimedEpoch = stakers[stakerID].paidUntilEpoch;
        require(epochStartTime(claimedEpoch + 1) >= lockedStakes[stakerID].endTime, "not all lockup rewards claimed");
    }

    function _isLockedDelegation(address delegator, uint256 toStakerID) view internal returns (bool) {
        return lockedDelegations[delegator][toStakerID].endTime != 0 && block.timestamp <= lockedDelegations[delegator][toStakerID].endTime;
    }

    function _isLockedStake(uint256 staker) view internal returns (bool) {
        return lockedStakes[staker].endTime != 0 && block.timestamp <= lockedStakes[staker].endTime;
    }

    function _checkPaidEpoch(uint256 paidUntilEpoch, uint256 fromEpoch, uint256 untilEpoch) view internal {
        require(paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");
    }

    function _checkAndUpgradeDelegationStorage(address delegator) internal {
        if (legacyDelegations[delegator].amount != 0) {
            delegations[delegator][legacyDelegations[delegator].toStakerID] = legacyDelegations[delegator];
            delete legacyDelegations[delegator];
        }
    }

    function _upgradeDelegationStorage(address delegator) external {
        require(legacyDelegations[delegator].amount != 0, "doesn't exist or already upgraded");
        _checkAndUpgradeDelegationStorage(delegator);
    }
}
