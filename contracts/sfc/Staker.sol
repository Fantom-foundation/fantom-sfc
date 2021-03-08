pragma solidity ^0.5.0;

import "./StakerConstants.sol";
import "./StakeTokenizer.sol";
import "../ownership/Ownable.sol";
import "../common/SafeMath.sol";
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

    uint256 private deleted0;
    uint256 private deleted1;
    uint256 private deleted2;

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

    address public stakeTokenizerAddress;

    struct _RewardsSet {
        uint256 unlockedReward;
        uint256 lockupBaseReward;
        uint256 lockupExtraReward;
        uint256 burntReward;
    }

    mapping(uint256 => uint256) public slashingRefundRatio; // validator ID -> (slashing refund ratio)

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
    // dagAddress is msg.sender (address to authenticate validator's consensus messages (DAG events))
    // sfcAdrress is msg.sender (address to authenticate validator inside SFC contract)
    function createStake(bytes memory) public payable {
        _createStake(msg.sender, msg.sender, msg.value);
    }

    function _createStake(address dagAddress, address sfcAddress, uint256 amount) internal {
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

    event IncreasedStake(uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    function _increaseStake(uint256 stakerID, uint256 amount) internal {
        uint256 newAmount = stakers[stakerID].stakeAmount.add(amount);
        stakers[stakerID].stakeAmount = newAmount;
        stakeTotalAmount = stakeTotalAmount.add(amount);
        emit IncreasedStake(stakerID, newAmount, amount);
    }

    // maxDelegatedLimit is a maximum amount which may be delegated to validator
    function maxDelegatedLimit(uint256 selfStake) internal pure returns (uint256) {
        return selfStake.mul(maxDelegatedRatio()).div(RATIO_UNIT);
    }

    event CreatedDelegation(address indexed delegator, uint256 indexed toStakerID, uint256 amount);

    function _createDelegation(address delegator, uint256 to) internal {
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

    // createDelegation creates new delegation to a given validator
    // Delegated amount is msg.value
    function createDelegation(uint256 to) external payable {
        _createDelegation(msg.sender, to);
    }

    event IncreasedDelegation(address indexed delegator, uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    function _increaseDelegation(address delegator, uint256 to, uint256 amount) internal {
        require(maxDelegatedLimit(stakers[to].stakeAmount) >= stakers[to].delegatedMe.add(amount), "staker's limit is exceeded");
        uint256 newAmount = delegations[delegator][to].amount.add(amount);

        delegations[delegator][to].amount = newAmount;
        stakers[to].delegatedMe = stakers[to].delegatedMe.add(amount);
        delegationsTotalAmount = delegationsTotalAmount.add(amount);

        emit IncreasedDelegation(delegator, to, newAmount, amount);

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

    function _calcDelegationLockupPenalty(address delegator, uint256 toStakerID, uint256 withdrawalAmount, uint256 delegationAmount) internal view returns (uint256) {
        uint256 penalty = delegationEarlyWithdrawalPenalty[delegator][toStakerID].mul(withdrawalAmount).div(delegationAmount);
        if (penalty >= withdrawalAmount) {
            penalty = withdrawalAmount.sub(1);
        }
        return penalty;
    }

    function calcValidatorLockupPenalty(uint256 stakerID, uint256 withdrawalAmount) public view returns (uint256) {
        if (!isStakeLockedUp(stakerID)) {
            return 0;
        }
        uint256 rewardRateEstimation = 142 * RATIO_UNIT / 1000; // 14.2% per maximum lockup duration
        uint256 lockupDuration = lockedStakes[stakerID].duration;
        uint256 lockupStart = lockedStakes[stakerID].endTime.sub(lockupDuration);
        uint256 fullRewardEstimation = withdrawalAmount.mul(rewardRateEstimation).mul(block.timestamp.sub(lockupStart)).div(maxLockupDuration()).div(RATIO_UNIT);
        _RewardsSet memory rewardsEstimation = _calcLockupReward(fullRewardEstimation, true, true, lockupDuration);
        uint256 penalty = rewardsEstimation.lockupBaseReward / 2 + rewardsEstimation.lockupExtraReward;
        if (penalty >= withdrawalAmount) {
            penalty = withdrawalAmount.sub(1);
        }
        return penalty;
    }

    // getValidatorRewardRatio returns ratio of full rewards which may be claimed by validator in a given epoch
    // if epoch is zero, then current sealed epoch is used
    // returns ratio with 6 decimals
    function getValidatorRewardRatio(uint256 stakerID) public view returns (uint256) {
        bool isLockedUp = isStakeLockedUp(stakerID);
        uint256 burnt = _calcLockupReward(RATIO_UNIT, isLockingFeatureActive(currentEpoch()), isLockedUp, lockedStakes[stakerID].duration).burntReward;
        return RATIO_UNIT - burnt;
    }

    // getDelegationRewardRatio returns ratio of full rewards which may be claimed by delegation in a given epoch
    // if epoch is zero, then current sealed epoch is used
    // returns ratio with 6 decimals
    function getDelegationRewardRatio(address delegator, uint256 toStakerID) public view returns (uint256) {
        bool isLockedUp = isDelegationLockedUp(delegator, toStakerID);
        uint256 burnt = _calcLockupReward(RATIO_UNIT, isLockingFeatureActive(currentEpoch()), isLockedUp, lockedDelegations[delegator][toStakerID].duration).burntReward;
        return RATIO_UNIT - burnt;
    }

    function _calcLockupReward(uint256 fullReward, bool isLockingFeature, bool isLockedUp, uint256 lockupDuration) private pure returns (_RewardsSet memory rewards) {
        rewards = _RewardsSet(0, 0, 0, 0);
        if (isLockingFeature) {
            uint256 maxLockupExtraRatio = RATIO_UNIT - unlockedRewardRatio();
            uint256 lockupExtraRatio = maxLockupExtraRatio.mul(lockupDuration).div(maxLockupDuration());

            if (isLockedUp) {
                rewards.unlockedReward = 0;
                rewards.lockupBaseReward = fullReward.mul(unlockedRewardRatio()).div(RATIO_UNIT);
                rewards.lockupExtraReward = fullReward.mul(lockupExtraRatio).div(RATIO_UNIT);
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

    function _calcValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 commission, uint256 compoundStake) internal view returns (_RewardsSet memory)  {
        uint256 fullReward = 0;
        {
            uint256 rawReward = _calcRawValidatorEpochReward(stakerID, epoch);

            uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount.add(compoundStake);
            uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
            uint256 totalStake = stake.add(delegatedTotal);
            if (totalStake == 0) {
                // avoid division by zero
                return _RewardsSet(0, 0, 0, 0);
            }
            uint256 weightedTotalStake = stake.add((delegatedTotal.mul(commission)).div(RATIO_UNIT));

            fullReward = rawReward.mul(weightedTotalStake).div(totalStake);
        }
        bool isLockedUp = _isStakeLockedUp(stakerID, epoch);

        return _calcLockupReward(fullReward, isLockingFeatureActive(epoch), isLockedUp, lockedStakes[stakerID].duration);
    }

    function _calcDelegationEpochReward(address delegator, uint256 toStakerID, uint256 epoch, uint256 commission, uint256 compoundStake) internal view returns (_RewardsSet memory) {
        uint256 fullReward = 0;
        {
            uint256 rawReward = _calcRawValidatorEpochReward(toStakerID, epoch);

            uint256 stake = epochSnapshots[epoch].validators[toStakerID].stakeAmount;
            uint256 delegatedTotal = epochSnapshots[epoch].validators[toStakerID].delegatedMe.add(compoundStake);
            uint256 totalStake = stake.add(delegatedTotal);
            if (totalStake == 0) {
                // avoid division by zero
                return _RewardsSet(0, 0, 0, 0);
            }
            uint256 delegationAmount = delegations[delegator][toStakerID].amount.add(compoundStake);
            uint256 weightedTotalStake = (delegationAmount.mul(RATIO_UNIT.sub(commission))).div(RATIO_UNIT);

            fullReward = rawReward.mul(weightedTotalStake).div(totalStake);
        }
        bool isLockedUp = _isDelegationLockedUp(delegator, toStakerID, epoch);

        return _calcLockupReward(fullReward, isLockingFeatureActive(epoch), isLockedUp, lockedDelegations[delegator][toStakerID].duration);
    }

    function withDefault(uint256 a, uint256 defaultA) pure private returns (uint256) {
        if (a == 0) {
            return defaultA;
        }
        return a;
    }

    function _calcDelegationLockupRewards(address delegator, uint256 toStakerID, uint256 fromEpoch, uint256 maxEpochs, bool compound) internal view returns (_RewardsSet memory, uint256, uint256) {
        Delegation memory delegation = delegations[delegator][toStakerID];
        fromEpoch = withDefault(fromEpoch, delegation.paidUntilEpoch + 1);
        if (delegation.amount == 0 || delegation.deactivatedTime != 0 || delegation.paidUntilEpoch >= fromEpoch) {
            return (_RewardsSet(0, 0, 0, 0), fromEpoch, 0);
        }

        _RewardsSet memory rewards = _RewardsSet(0, 0, 0, 0);

        uint256 e;
        for (e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            uint256 compoundStake = 0;
            if (compound) {
                compoundStake = rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
            }
            _RewardsSet memory eRewards = _calcDelegationEpochReward(delegator, toStakerID, e, validatorCommission(), compoundStake);
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
    // _fromEpoch is a starting epoch from which rewards are calculated (including). If 0, then lowest not claimed epoch iss substituted.
    // maxEpochs is a maximum number of epoch to calculate rewards for.
    function calcDelegationRewards(address delegator, uint256 toStakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcDelegationLockupRewards(delegator, toStakerID, _fromEpoch, maxEpochs, false);
        return (rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward, fromEpoch, untilEpoch);
    }

    // Returns the pending rewards for a given delegator, first calculated epoch, last calculated epoch
    // The function calculates an approximation of rewards in a case if delegator was delegating his rewards every epoch
    // _fromEpoch is a starting epoch from which rewards are calculated (including). If 0, then lowest not claimed epoch iss substituted.
    // maxEpochs is a maximum number of epoch to calculate rewards for.
    function calcDelegationCompoundRewards(address delegator, uint256 toStakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcDelegationLockupRewards(delegator, toStakerID, _fromEpoch, maxEpochs, true);
        return (rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward, fromEpoch, untilEpoch);
    }

    function _calcValidatorLockupRewards(uint256 stakerID, uint256 fromEpoch, uint256 maxEpochs, bool compound) internal view returns (_RewardsSet memory, uint256, uint256) {
        fromEpoch = withDefault(fromEpoch, stakers[stakerID].paidUntilEpoch + 1);

        if (stakers[stakerID].paidUntilEpoch >= fromEpoch) {
            return (_RewardsSet(0, 0, 0, 0), fromEpoch, 0);
        }

        _RewardsSet memory rewards = _RewardsSet(0, 0, 0, 0);

        uint256 e;
        for (e = fromEpoch; e <= currentSealedEpoch && e < fromEpoch + maxEpochs; e++) {
            uint256 compoundStake = 0;
            if (compound) {
                compoundStake = rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
            }
            _RewardsSet memory eRewards = _calcValidatorEpochReward(stakerID, e, validatorCommission(), compoundStake);
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
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcValidatorLockupRewards(stakerID, _fromEpoch, maxEpochs, false);
        return (rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward, fromEpoch, untilEpoch);
    }

    // Returns the pending rewards for a given validator, first claimed epoch, last claimed epoch
    // The function calculates an approximation of rewards in a case if validator was staking his rewards every epoch
    // _fromEpoch is starting epoch which rewards are calculated (including). If 0, then it's lowest not claimed epoch
    // maxEpochs is maximum number of epoch to calc rewards for. Set it to your chunk size.
    function calcValidatorCompoundRewards(uint256 stakerID, uint256 _fromEpoch, uint256 maxEpochs) public view returns (uint256, uint256, uint256) {
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcValidatorLockupRewards(stakerID, _fromEpoch, maxEpochs, true);
        return (rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward, fromEpoch, untilEpoch);
    }

    event ClaimedDelegationReward(address indexed from, uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    function _claimDelegationRewards(uint256 maxEpochs, uint256 toStakerID, bool compound) internal {
        address payable delegator = msg.sender;
        Delegation storage delegation = delegations[delegator][toStakerID];
        _checkNotDeactivatedDelegation(delegator, toStakerID);
        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcDelegationLockupRewards(delegator, toStakerID, 0, maxEpochs, compound);

        uint256 rewardsAll = rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
        _checkPaidEpoch(delegation.paidUntilEpoch, fromEpoch, untilEpoch);

        delegation.paidUntilEpoch = untilEpoch;
        delegationEarlyWithdrawalPenalty[delegator][toStakerID] += rewards.lockupBaseReward / 2 + rewards.lockupExtraReward;
        totalBurntLockupRewards += rewards.burntReward;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        if (compound) {
            _increaseDelegation(delegator, toStakerID, rewardsAll);
        } else {
            delegator.transfer(rewardsAll);
        }

        emit ClaimedDelegationReward(delegator, toStakerID, rewardsAll, fromEpoch, untilEpoch);
    }

    // Claim the pending rewards for a given delegator (sender)
    // Rewards are sent to sender's address
    // toStakerID is a stakerID of delegation
    // maxEpochs is maximum number of epoch to calc rewards for.
    function claimDelegationRewards(uint256 maxEpochs, uint256 toStakerID) external {
        _claimDelegationRewards(maxEpochs, toStakerID, false);
    }

    // Claim the pending rewards for a given delegator (sender)
    // Rewards are delegated to the validator
    // toStakerID is a stakerID of delegation
    // maxEpochs is maximum number of epoch to calc rewards for.
    function claimDelegationCompoundRewards(uint256 maxEpochs, uint256 toStakerID) external {
        _claimDelegationRewards(maxEpochs, toStakerID, true);
    }

    event ClaimedValidatorReward(uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    function _claimValidatorRewards(uint256 maxEpochs, bool compound) internal {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        _checkExistStaker(stakerID);

        (_RewardsSet memory rewards, uint256 fromEpoch, uint256 untilEpoch) = _calcValidatorLockupRewards(stakerID, 0, maxEpochs, compound);

        uint256 rewardsAll = rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
        _checkPaidEpoch(stakers[stakerID].paidUntilEpoch, fromEpoch, untilEpoch);

        stakers[stakerID].paidUntilEpoch = untilEpoch;
        totalBurntLockupRewards += rewards.burntReward;
        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        if (compound) {
            _increaseStake(stakerID, rewardsAll);
        } else {
            stakerSfcAddr.transfer(rewardsAll);
        }

        emit ClaimedValidatorReward(stakerID, rewardsAll, fromEpoch, untilEpoch);
    }

    // claimValidatorRewards claims the pending rewards for a given stakerID (sender)
    // Rewards are sent to sender's address
    // maxEpochs is maximum number of epoch to calc rewards for.
    // Deactivated validators are still allowed to withdraw old rewards
    function claimValidatorRewards(uint256 maxEpochs) external {
        _claimValidatorRewards(maxEpochs, false);
    }

    // claimValidatorCompoundRewards claims the pending rewards for a given stakerID (sender)
    // Rewards are staked
    // maxEpochs is maximum number of epoch to calc rewards for.
    // Deactivated validators are still allowed to withdraw old rewards
    function claimValidatorCompoundRewards(uint256 maxEpochs) external {
        _claimValidatorRewards(maxEpochs, true);
    }

    event UnstashedRewards(address indexed auth, address indexed receiver, uint256 rewards);

    // Transfer the claimed rewards to account
    function unstashRewards(address payable receiver) external {
        address auth = receiver;
        uint256 rewards = rewardsStash[auth][0].amount;
        require(rewards != 0, "no rewards");

        delete rewardsStash[auth][0];

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        receiver.transfer(rewards);

        emit UnstashedRewards(auth, receiver, rewards);
    }

    event PreparedToWithdrawStake(uint256 indexed stakerID); // previous name for DeactivatedStake
    event DeactivatedStake(uint256 indexed stakerID);

    // prepareToWithdrawStake starts validator withdrawal
    function prepareToWithdrawStake() external {
        address stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        _checkNotDeactivatedStaker(stakerID);
        _checkClaimedStaker(stakerID);
        StakeTokenizer(stakeTokenizerAddress).checkAllowedToWithdrawStake(stakerSfcAddr, stakerID);

        uint256 stakeAmount = stakers[stakerID].stakeAmount;
        uint256 penalty = calcValidatorLockupPenalty(stakerID, stakeAmount);
        // validator will receive less funds on withdrawal if penalty > 0
        stakers[stakerID].stakeAmount -= penalty;
        stakeTotalAmount -= penalty;

        stakers[stakerID].deactivatedEpoch = currentEpoch();
        stakers[stakerID].deactivatedTime = block.timestamp;

        emit DeactivatedStake(stakerID);
    }

    event CreatedWithdrawRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, bool delegation, uint256 amount);

    // prepareToWithdrawStakePartial starts withdrawal of a part of validator stake
    function prepareToWithdrawStakePartial(uint256 wrID, uint256 amount) external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        _checkNotDeactivatedStaker(stakerID);
        _checkClaimedStaker(stakerID);
        StakeTokenizer(stakeTokenizerAddress).checkAllowedToWithdrawStake(stakerSfcAddr, stakerID);
        // avoid confusing wrID and amount
        require(amount >= minStakeDecrease(), "too small amount");

        uint256 penalty = calcValidatorLockupPenalty(stakerID, amount);

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 totalAmount = stakers[stakerID].stakeAmount;
        require(amount + minStake() <= totalAmount, "must leave at least minStake");
        uint256 newAmount = totalAmount - amount;
        require(maxDelegatedLimit(newAmount) >= stakers[stakerID].delegatedMe, "too much delegations");
        require(withdrawalRequests[stakerSfcAddr][wrID].amount == 0, "wrID already exists");

        stakers[stakerID].stakeAmount -= amount;
        withdrawalRequests[stakerSfcAddr][wrID].stakerID = stakerID;
        // validator will receive less funds on withdrawal if penalty > 0
        withdrawalRequests[stakerSfcAddr][wrID].amount = amount - penalty;
        withdrawalRequests[stakerSfcAddr][wrID].epoch = currentEpoch();
        withdrawalRequests[stakerSfcAddr][wrID].time = block.timestamp;

        emit CreatedWithdrawRequest(stakerSfcAddr, stakerSfcAddr, stakerID, wrID, false, amount);

        _syncStaker(stakerID);
    }

    function getSlashingPenalty(uint256 amount, bool isCheater, uint256 refundRatio) internal pure returns(uint256 penalty) {
        if (!isCheater || refundRatio >= 1e18) {
            return 0;
        }
        return amount.mul(1e18 - refundRatio).div(1e18);
    }

    event WithdrawnStake(uint256 indexed stakerID, uint256 penalty);

    // withdrawStake finalises validator withdrawal
    function withdrawStake() external {
        address payable stakerSfcAddr = msg.sender;
        uint256 stakerID = _sfcAddressToStakerID(stakerSfcAddr);
        require(stakers[stakerID].deactivatedTime != 0, "staker wasn't deactivated");
        if (!isSlashed(stakerID)) {
            require(block.timestamp >= stakers[stakerID].deactivatedTime + stakeLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= stakers[stakerID].deactivatedEpoch + stakeLockPeriodEpochs(), "not enough epochs passed");
        }

        address stakerDagAddr = stakers[stakerID].dagAddress;
        uint256 stake = stakers[stakerID].stakeAmount;
        uint256 status = stakers[stakerID].status;
        bool isCheater = status & CHEATER_MASK != 0;
        uint256 penalty = getSlashingPenalty(stake, isCheater, slashingRefundRatio[stakerID]);
        delete stakers[stakerID];
        delete stakerIDs[stakerSfcAddr];
        delete stakerIDs[stakerDagAddr];

        if (status != 0) {
            // write status back into storage
            stakers[stakerID].status = status;
        }
        stakersNum--;
        stakeTotalAmount = stakeTotalAmount.sub(stake);

        slashedStakeTotalAmount = slashedStakeTotalAmount.add(penalty);

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        require(stake > penalty, "stake is fully slashed");
        stakerSfcAddr.transfer(stake.sub(penalty));

        emit WithdrawnStake(stakerID, penalty);
    }

    event PreparedToWithdrawDelegation(address indexed delegator, uint256 indexed stakerID); // previous name for DeactivatedDelegation
    event DeactivatedDelegation(address indexed delegator, uint256 indexed stakerID);

    // prepareToWithdrawDelegation starts delegation withdrawal
    function prepareToWithdrawDelegation(uint256 toStakerID) external {
        _prepareToWithdrawDelegation(msg.sender, toStakerID);
    }

    function prepareToWithdrawStuckDelegation(address delegator, uint256 toStakerID) onlyOwner external {
        Delegation storage delegation = delegations[delegator][toStakerID];
        require(delegation.paidUntilEpoch <= 1200, "delegation isn't stuck because claimed rewards recently");
        _prepareToWithdrawDelegation(delegator, toStakerID);
    }

    function _prepareToWithdrawDelegation(address delegator, uint256 toStakerID) internal {
        Delegation storage delegation = delegations[delegator][toStakerID];
        _checkNotDeactivatedDelegation(delegator, toStakerID);
        StakeTokenizer(stakeTokenizerAddress).checkAllowedToWithdrawStake(delegator, toStakerID);
        _checkClaimedDelegation(delegator, toStakerID);

        delegation.deactivatedEpoch = currentEpoch();
        delegation.deactivatedTime = block.timestamp;
        uint256 delegationAmount = delegation.amount;

        if (stakers[toStakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[toStakerID].delegatedMe = stakers[toStakerID].delegatedMe.sub(delegationAmount);
        }

        uint256 penalty = 0;
        if (isDelegationLockedUp(delegator, toStakerID)) {
            penalty = _calcDelegationLockupPenalty(delegator, toStakerID, delegationAmount, delegationAmount);
            // forgive penalty
            delegationEarlyWithdrawalPenalty[delegator][toStakerID] -= penalty;
        }
        // delegator will receive less funds on withdrawal if penalty > 0
        delegation.amount -= penalty;
        delegationsTotalAmount -= penalty;

        emit DeactivatedDelegation(delegator, toStakerID);

        _syncDelegation(delegator, toStakerID);
        if (stakers[toStakerID].stakeAmount != 0) {
            _syncStaker(toStakerID);
        }
    }

    // prepareToWithdrawDelegation starts withdrawal for a part of delegation stake
    function prepareToWithdrawDelegationPartial(uint256 wrID, uint256 toStakerID, uint256 amount) external {
        address payable delegator = msg.sender;
        Delegation storage delegation = delegations[delegator][toStakerID];
        _checkNotDeactivatedDelegation(delegator, toStakerID);
        StakeTokenizer(stakeTokenizerAddress).checkAllowedToWithdrawStake(delegator, toStakerID);
        // previous rewards must be claimed because rewards calculation depends on current delegation amount
        _checkClaimedDelegation(delegator, toStakerID);
        // avoid confusing wrID and amount
        require(amount >= minDelegationDecrease(), "too small amount");

        // don't allow to withdraw full as a request, because amount==0 originally meant "not existing"
        uint256 totalAmount = delegation.amount;
        require(amount + minDelegation() <= totalAmount, "must leave at least minDelegation");

        require(withdrawalRequests[delegator][wrID].amount == 0, "wrID already exists");

        uint256 penalty = 0;
        if (isDelegationLockedUp(delegator, toStakerID)) {
            penalty = _calcDelegationLockupPenalty(delegator, toStakerID, amount, totalAmount);
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
        if (stakers[toStakerID].stakeAmount != 0) {
            _syncStaker(toStakerID);
        }
    }

    event WithdrawnDelegation(address indexed delegator, uint256 indexed toStakerID, uint256 penalty);

    // withdrawDelegation finalises delegation withdrawal
    function withdrawDelegation(uint256 toStakerID) external {
        _withdrawDelegation(msg.sender, toStakerID);
    }

    function withdrawStuckDelegation(address payable delegator, uint256 toStakerID) onlyOwner external {
        Delegation storage delegation = delegations[delegator][toStakerID];
        require(delegation.paidUntilEpoch <= 1200, "delegation isn't stuck because claimed rewards recently");
        _withdrawDelegation(delegator, toStakerID);
    }

    function _withdrawDelegation(address payable delegator, uint256 toStakerID) internal {
        Delegation memory delegation = delegations[delegator][toStakerID];
        require(delegation.deactivatedTime != 0, "delegation wasn't deactivated");
        if (stakers[toStakerID].stakeAmount != 0 && !isSlashed(toStakerID)) {
            // if validator hasn't withdrawn already, then don't allow to withdraw delegation right away
            require(block.timestamp >= delegation.deactivatedTime + delegationLockPeriodTime(), "not enough time passed");
            require(currentEpoch() >= delegation.deactivatedEpoch + delegationLockPeriodEpochs(), "not enough epochs passed");
        }
        bool isCheater = isSlashed(toStakerID);
        uint256 delegationAmount = delegation.amount;
        uint256 penalty = getSlashingPenalty(delegationAmount, isCheater, slashingRefundRatio[toStakerID]);
        delete delegations[delegator][toStakerID];
        delete lockedDelegations[delegator][toStakerID];
        delete delegationEarlyWithdrawalPenalty[delegator][toStakerID];

        delegationsNum--;

        delegationsTotalAmount = delegationsTotalAmount.sub(delegationAmount);

        slashedDelegationsTotalAmount = slashedDelegationsTotalAmount.add(penalty);

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        require(delegationAmount > penalty, "stake is fully slashed");
        delegator.transfer(delegationAmount.sub(penalty));

        emit WithdrawnDelegation(delegator, toStakerID, penalty);
    }

    event PartialWithdrawnByRequest(address indexed auth, address indexed receiver, uint256 indexed stakerID, uint256 wrID, bool delegation, uint256 penalty);

    // partialWithdrawByRequest finalises partial withdrawal by WithdrawalRequestID
    function partialWithdrawByRequest(uint256 wrID) external {
        address auth = msg.sender;
        address payable receiver = msg.sender;
        require(withdrawalRequests[auth][wrID].time != 0, "request doesn't exist");
        bool delegation = withdrawalRequests[auth][wrID].delegation;

        uint256 stakerID = withdrawalRequests[auth][wrID].stakerID;
        if (!isSlashed(stakerID)) {
            if (delegation && stakers[stakerID].stakeAmount != 0) {
                // if validator hasn't withdrawn already, then don't allow to withdraw delegation right away
                require(block.timestamp >= withdrawalRequests[auth][wrID].time + delegationLockPeriodTime(), "not enough time passed");
                require(currentEpoch() >= withdrawalRequests[auth][wrID].epoch + delegationLockPeriodEpochs(), "not enough epochs passed");
            } else if (!delegation) {
                require(block.timestamp >= withdrawalRequests[auth][wrID].time + stakeLockPeriodTime(), "not enough time passed");
                require(currentEpoch() >= withdrawalRequests[auth][wrID].epoch + stakeLockPeriodEpochs(), "not enough epochs passed");
            }
        }

        bool isCheater = isSlashed(stakerID);
        uint256 amount = withdrawalRequests[auth][wrID].amount;
        uint256 penalty = getSlashingPenalty(amount, isCheater, slashingRefundRatio[stakerID]);
        delete withdrawalRequests[auth][wrID];

        if (delegation) {
            delegationsTotalAmount = delegationsTotalAmount.sub(amount);
        } else {
            stakeTotalAmount = stakeTotalAmount.sub(amount);
        }

        if (delegation) {
            slashedDelegationsTotalAmount = slashedDelegationsTotalAmount.add(penalty);
        } else {
            slashedStakeTotalAmount = slashedStakeTotalAmount.add(penalty);
        }

        // It's important that we transfer after erasing (protection against Re-Entrancy)
        require(amount > penalty, "stake is fully slashed");
        receiver.transfer(amount.sub(penalty));

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

    function _updateMinGasPrice(uint256 minGasPrice) onlyOwner external {
        emit UpdatedMinGasPrice(minGasPrice);
    }

    function _activateNetworkUpgrade(uint256 minVersion) onlyOwner external {
        emit NetworkUpgradeActivated(minVersion);
    }

    function _startNetworkMigration(uint256 version) onlyOwner external {
        emit NetworkMigrationStarted(version);
    }

    function _updateStakeTokenizerAddress(address addr) onlyOwner external {
        stakeTokenizerAddress = addr;
    }

    function updateSlashingRefundRatio(uint256 validatorID, uint256 refundRatio) onlyOwner external {
        require(isSlashed(validatorID), "validator isn't slashed");
        require(refundRatio <= 1e18, "must be less than or equal to 1.0 = 1e18");
        slashingRefundRatio[validatorID] = refundRatio;
        emit UpdatedSlashingRefundRatio(validatorID, refundRatio);
    }

    function startLockedUp(uint256 epochNum) onlyOwner external {
        require(epochNum > currentSealedEpoch, "can't start in the past");
        require(firstLockedUpEpoch == 0 || firstLockedUpEpoch > currentSealedEpoch, "feature was started");
        firstLockedUpEpoch = epochNum;
    }

    event LockingStake(uint256 indexed stakerID, uint256 fromEpoch, uint256 endTime);

    // lockUpStake locks validator's stake
    // Locked validator isn't allowed to withdraw until lockup period is elapsed
    function lockUpStake(uint256 lockDuration) external {
        require(isLockingFeatureActive(currentEpoch()), "feature was not activated");
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        _checkActiveStaker(stakerID);
        require(lockDuration >= minLockupDuration() && lockDuration <= maxLockupDuration(), "incorrect duration");
        uint256 endTime = block.timestamp.add(lockDuration);
        require(!isStakeLockedUp(stakerID), "already locked up");
        _checkClaimedStakerLockupRewards(stakerID);

        lockedStakes[stakerID] = LockedAmount(currentEpoch(), endTime, lockDuration);
        emit LockingStake(stakerID, currentEpoch(), endTime);
    }

    event LockingDelegation(address indexed delegator, uint256 indexed stakerID, uint256 fromEpoch, uint256 endTime);

    // lockUpDelegation locks delegation stake
    function lockUpDelegation(uint256 lockDuration, uint256 toStakerID) external {
        require(isLockingFeatureActive(currentEpoch()), "feature was not activated");
        address delegator = msg.sender;
        _checkExistDelegation(delegator, toStakerID);
        _checkActiveStaker(toStakerID);
        require(lockDuration >= minLockupDuration() && lockDuration <= maxLockupDuration(), "incorrect duration");
        uint256 endTime = block.timestamp.add(lockDuration);
        require(lockedStakes[toStakerID].endTime >= endTime, "staker's locking will finish first");
        require(!isDelegationLockedUp(delegator, toStakerID), "already locked up");
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

    function epochEndTime(uint256 epoch) view internal returns (uint256) {
        return epochSnapshots[epoch].endTime;
    }

    function _checkClaimedDelegationLockupRewards(address delegator, uint256 toStakerID) view internal {
        uint256 claimedEpoch = delegations[delegator][toStakerID].paidUntilEpoch;
        require(epochEndTime(claimedEpoch) >= lockedDelegations[delegator][toStakerID].endTime, "not all lockup rewards claimed");
    }

    function _checkClaimedStakerLockupRewards(uint256 stakerID) view internal {
        uint256 claimedEpoch = stakers[stakerID].paidUntilEpoch;
        require(epochEndTime(claimedEpoch) >= lockedStakes[stakerID].endTime, "not all lockup rewards claimed");
    }

    // isDelegationLockedUp returns true if delegation is locked up
    function isDelegationLockedUp(address delegator, uint256 toStakerID) view public returns (bool) {
        return lockedDelegations[delegator][toStakerID].endTime != 0 && block.timestamp <= lockedDelegations[delegator][toStakerID].endTime;
    }

    // isStakeLockedUp returns true if validator is locked up
    function isStakeLockedUp(uint256 staker) view public returns (bool) {
        return lockedStakes[staker].endTime != 0 && block.timestamp <= lockedStakes[staker].endTime;
    }

    function _isStakeLockedUp(uint256 stakerID, uint256 epoch) internal view returns (bool) {
        return lockedStakes[stakerID].fromEpoch <= epoch && lockedStakes[stakerID].endTime > epochEndTime(epoch);
    }

    function _isDelegationLockedUp(address delegator, uint256 toStakerID, uint256 epoch) internal view returns (bool) {
        return lockedDelegations[delegator][toStakerID].fromEpoch <= epoch && lockedDelegations[delegator][toStakerID].endTime > epochEndTime(epoch);
    }

    function isLockingFeatureActive(uint256 epoch) view internal returns (bool) {
        return firstLockedUpEpoch > 0 && epoch >= firstLockedUpEpoch;
    }

    function isSlashed(uint256 stakerID) view public returns (bool) {
        return stakers[stakerID].status & CHEATER_MASK != 0;
    }

    function _checkPaidEpoch(uint256 paidUntilEpoch, uint256 fromEpoch, uint256 untilEpoch) view internal {
        require(paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= currentSealedEpoch, "future epoch");
        require(untilEpoch >= fromEpoch, "no epochs claimed");
    }
}
