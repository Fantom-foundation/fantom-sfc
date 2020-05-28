pragma solidity ^0.5.0;

import "./SafeMath.sol";

interface ILiquidityPool {
    function deposit(uint256 _value_native) external payable;
}

contract StakersConstants {
    uint256 public constant percentUnit = 1000000;

    function blockRewardPerSecond() public pure returns (uint256) {
        return 8.241994292233796296 * 1e18; // 712108.306849 FTM per day
    }

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
        return 15 * percentUnit; // 1500%
    }

    function validatorCommission() public pure returns (uint256) {
        return (15 * percentUnit) / 100; // 15%
    }

    function contractCommission() public pure returns (uint256) {
        return (30 * percentUnit) / 100; // 30%
    }

    function stakeLockPeriodTime() public pure returns (uint256) {
        return 60 * 60 * 24 * 7; // 7 days
    }

    function stakeLockPeriodEpochs() public pure returns (uint256) {
        return 3;
    }

    function deleagtionLockPeriodTime() public pure returns (uint256) {
        return 60 * 60 * 24 * 7; // 7 days
    }

    function deleagtionLockPeriodEpochs() public pure returns (uint256) {
        return 3;
    }
}

contract Stakers is StakersConstants {
    using SafeMath for uint256;

    struct Delegation {
        bool rewardToFUSD; // transfer all rewards to LiquidityPool fUSD user balance

        uint256 createdEpoch;
        uint256 createdTime;

        uint256 deactivatedEpoch;
        uint256 deactivatedTime;

        uint256 amount;
        uint256 paidUntilEpoch;
        uint256 toStakerID;
    }

    struct ValidationStake {
        bool isCheater; // written by consensus outside
        bool rewardToFUSD; // transfer all rewards to LiquidityPool fUSD user balance

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
        uint256 validatingPower;
        uint256 stakeAmount;
        uint256 delegatedMe;
    }

    struct EpochSnapshot {
        mapping(uint256 => ValidatorMerit) validators; //  stakerID -> ValidatorMerit

        uint256 endTime;
        uint256 duration;
        uint256 epochFee;
        uint256 totalValidatingPower;
    }

    uint256 public currentSealedEpoch; // written by consensus outside
    mapping(uint256 => EpochSnapshot) public epochSnapshots; // written by consensus outside
    mapping(uint256 => ValidationStake) public stakers; // stakerID -> stake
    mapping(address => uint256) public stakerIDs; // staker address -> stakerID

    uint256 public stakersLastID;
    uint256 public stakersNum;
    uint256 public stakeTotalAmount;
    uint256 public delegationsNum;
    uint256 public delegationsTotalAmount;

    address internal liquidityPool;

    mapping(address => Delegation) public delegations; // delegationID -> delegation

    /*
    Methods
    */

    function setLiquidityPool(address pool) external {
        liquidityPool = pool;
    }
    function setDelegationRewardToFUSD(address delegator, bool isRewardToFUSD) external returns(bool prevState) {
        require(delegations[delegator].createdTime != 0, "delegator should by present in SFC contract");

        prevState = delegations[delegator].rewardToFUSD;
        delegations[delegator].rewardToFUSD = isRewardToFUSD;
    }
    function setStakerRewardToFUSD(address staker, bool isRewardToFUSD) external returns (bool prevState) {
        uint256 stakerID = stakerIDs[staker];
        require(stakerID != 0, "stakerID should by present in SFC contract");
        require(stakers[stakerID].createdTime != 0, "staker should by present in SFC contract");

        prevState = stakers[stakerID].rewardToFUSD;
        stakers[stakerID].rewardToFUSD = isRewardToFUSD;
    }

    function getEpochValidator(uint256 e, uint256 v) external view returns (uint256, uint256, uint256) {
        return (epochSnapshots[e].validators[v].validatingPower,
                epochSnapshots[e].validators[v].stakeAmount,
                epochSnapshots[e].validators[v].delegatedMe);
    }

    function currentEpoch() public view returns (uint256) {
        return currentSealedEpoch + 1;
    }

    event CreatedStake(uint256 indexed stakerID, address indexed stakerAddress, uint256 amount);

    function createStake() external payable {
        implCreateStake();
    }

    function implCreateStake() internal {
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

        stakersNum++;
        stakeTotalAmount = stakeTotalAmount.add(msg.value);
        emit CreatedStake(stakerID, staker, msg.value);
    }

    event IncreasedStake(uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    function increaseStake() external payable {
        address staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];

        require(msg.value >= minStakeIncrease(), "insufficient amount");
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker shouldn't be deactivated yet");
        require(stakers[stakerID].isCheater == false, "staker shouldn't be cheater");

        uint256 newAmount = stakers[stakerID].stakeAmount.add(msg.value);
        stakers[stakerID].stakeAmount = newAmount;
        stakeTotalAmount = stakeTotalAmount.add(msg.value);
        emit IncreasedStake(stakerID, newAmount, msg.value);
    }

    event CreatedDelegation(address indexed from, uint256 indexed toStakerID, uint256 amount);

    function createDelegation(uint256 to) external payable {
        address from = msg.sender;

        require(stakers[to].stakeAmount != 0, "staker doesn't exist");
        require(stakers[to].isCheater == false, "staker shouldn't be cheater");
        require(msg.value >= minDelegation(), "insufficient amount for delegation");
        require(delegations[from].amount == 0, "delegation already exists");
        require(stakerIDs[from] == 0, "already staking");
        require((stakers[to].stakeAmount.mul(maxDelegatedRatio())).div(percentUnit) >= stakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        delegations[from] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(from, to, msg.value);
    }

    function calcTotalReward(uint256 stakerID, uint256 epoch) view public returns (uint256) {
        uint256 totalValidatingPower = epochSnapshots[epoch].totalValidatingPower;
        uint256 validatingPower = epochSnapshots[epoch].validators[stakerID].validatingPower;
        require(totalValidatingPower != 0, "total validating power can't be zero");

        // base reward
        uint256 reward = epochSnapshots[epoch].duration.mul(blockRewardPerSecond()).mul(validatingPower).div(totalValidatingPower);
        // fee reward except contractCommission
        uint256 feeReward = epochSnapshots[epoch].epochFee.mul(validatingPower).div(totalValidatingPower);
        feeReward = feeReward.mul(percentUnit - contractCommission()).div(percentUnit);

        return reward.add(feeReward);
    }

    function calcValidatorReward(uint256 stakerID, uint256 epoch) view public returns (uint256) {
        uint256 fullReward = calcTotalReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        uint256 weightedTotalStake = stake.add((delegatedTotal.mul(validatorCommission())).div(percentUnit));
        return (fullReward.mul(weightedTotalStake)).div(totalStake);
    }

    function calcDelegationReward(uint256 stakerID, uint256 epoch, uint256 delegatedAmount) view public returns (uint256) {
        uint256 fullReward = calcTotalReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        uint256 weightedTotalStake = (delegatedAmount.mul(percentUnit.sub(validatorCommission()))).div(percentUnit);
        return (fullReward.mul(weightedTotalStake)).div(totalStake);
    }

    function withDefault(uint256 a, uint256 defaultA) pure private returns(uint256) {
        if (a == 0) {
            return defaultA;
        }
        return a;
    }

    event ClaimedDelegationReward(address indexed from, uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    function claimDelegationReward(uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable from = msg.sender;

        require(delegations[from].amount != 0, "delegation doesn't exist");
        require(delegations[from].deactivatedTime == 0, "delegation shouldn't be deactivated yet");

        uint256 paidUntilEpoch = delegations[from].paidUntilEpoch;
        uint256 delegatedAmount = delegations[from].amount;
        uint256 stakerID = delegations[from].toStakerID;
        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch + 1);
        uint256 untilEpoch = withDefault(_untilEpoch, currentSealedEpoch);

        require(paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= untilEpoch, "invalid fromEpoch");
        require(untilEpoch <= currentSealedEpoch, "invalid untilEpoch");

        uint256 reward = 0;
        for (uint256 e = fromEpoch; e <= untilEpoch; e++) {
            reward += calcDelegationReward(stakerID, e, delegatedAmount); // SS safeMath
        }
        delegations[from].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        if (delegations[from].rewardToFUSD && liquidityPool != address(0)) {
            ILiquidityPool(liquidityPool).deposit(reward);
        } else {
            msg.sender.transfer(reward);
        }

        emit ClaimedDelegationReward(from, stakerID, reward, fromEpoch, untilEpoch);
    }

    event ClaimedValidatorReward(uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // may be already deactivated, but still allowed to withdraw old rewards
    function claimValidatorReward(uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");

        uint256 paidUntilEpoch = stakers[stakerID].paidUntilEpoch;

        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch + 1);
        uint256 untilEpoch = withDefault(_untilEpoch, currentSealedEpoch);

        require(paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= untilEpoch, "invalid fromEpoch");
        require(untilEpoch <= currentSealedEpoch, "invalid untilEpoch");

        uint256 reward = 0;
        for (uint256 e = fromEpoch; e <= untilEpoch; e++) {
            reward += calcValidatorReward(stakerID, e);
        }
        stakers[stakerID].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        if (stakers[stakerID].rewardToFUSD && liquidityPool != address(0)) {
            ILiquidityPool(liquidityPool).deposit(reward);
        } else {
            staker.transfer(reward);
        }

        emit ClaimedValidatorReward(stakerID, reward, fromEpoch, untilEpoch);
    }

    event PreparedToWithdrawStake(uint256 indexed stakerID);

    // deactivate stake, to be able to withdraw later
    function prepareToWithdrawStake() external {
        address staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(stakers[stakerID].deactivatedTime == 0, "staker shouldn't be deactivated yet");

        stakers[stakerID].deactivatedEpoch = currentEpoch();
        stakers[stakerID].deactivatedTime = block.timestamp;

        emit PreparedToWithdrawStake(stakerID);
    }

    event WithdrawnStake(uint256 indexed stakerID, bool isCheater);

    function withdrawStake() external {
        address payable staker = msg.sender;
        uint256 stakerID = stakerIDs[staker];
        require(stakers[stakerID].deactivatedTime != 0, "staker wasn't deactivated");
        require(block.timestamp >= stakers[stakerID].deactivatedTime + stakeLockPeriodTime(), "not enough time passed");
        require(currentEpoch() >= stakers[stakerID].deactivatedEpoch + stakeLockPeriodEpochs(), "not enough epochs passed");

        uint256 stake = stakers[stakerID].stakeAmount;
        bool isCheater = stakers[stakerID].isCheater;
        delete stakers[stakerID];
        delete stakerIDs[staker];

        stakersNum--;
        stakeTotalAmount = stakeTotalAmount.sub(stake);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            staker.transfer(stake);
        }

        emit WithdrawnStake(stakerID, isCheater);
    }

    event PreparedToWithdrawDelegation(address indexed from);

    // deactivate delegation, to be able to withdraw later
    function prepareToWithdrawDelegation() external {
        address from = msg.sender;
        require(delegations[from].amount != 0, "delegation doesn't exist");
        require(delegations[from].deactivatedTime == 0, "delegation shouldn't be deactivated yet");

        delegations[from].deactivatedEpoch = currentEpoch();
        delegations[from].deactivatedTime = block.timestamp;
        uint256 stakerID = delegations[from].toStakerID;
        uint256 delegatedAmount = delegations[from].amount;
        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegatedAmount);
        }

        emit PreparedToWithdrawDelegation(from);
    }

    event WithdrawnDelegation(uint256 indexed stakerID, bool isCheater);

    function withdrawDelegation() external {
        address payable from = msg.sender;
        require(delegations[from].deactivatedTime != 0, "delegation wasn't deactivated");
        require(block.timestamp >= delegations[from].deactivatedTime + deleagtionLockPeriodTime(), "not enough time passed");
        require(currentEpoch() >= delegations[from].deactivatedEpoch + deleagtionLockPeriodEpochs(), "not enough epochs passed");
        uint256 stakerID = delegations[from].toStakerID;
        bool isCheater = stakers[stakerID].isCheater;
        uint256 delegatedAmount = delegations[from].amount;
        delete delegations[from];

        delegationsNum--;
        delegationsTotalAmount = delegationsTotalAmount.sub(delegatedAmount);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            from.transfer(delegatedAmount);
        }

        emit WithdrawnDelegation(stakerID, isCheater);
    }
}

contract TestStakers is Stakers {
    function stakeLockPeriodTime() public pure returns (uint256) {
        return 1 * 60;
    }

    function deleagtionLockPeriodTime() public pure returns (uint256) {
        return 1 * 60;
    }
}

contract UnitTestStakers is Stakers {
    uint256[] public stakerIDsArr;

    function blockRewardPerSecond() public pure returns (uint256) {
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

    function _markValidationStakeAsCheater(uint256 stakerID, bool status) external {
        if (stakers[stakerID].stakeAmount != 0) {
            stakers[stakerID].isCheater = status;
        }
    }

    function _createStake() external payable {
        stakerIDsArr.push(stakersLastID + 1); // SS Check existing?
        super.implCreateStake();
    }

    function _makeEpochSnapshots(uint256 optionalDuration) external returns(uint256) {
        currentSealedEpoch++;
        EpochSnapshot storage newSnapshot = epochSnapshots[currentSealedEpoch];
        uint256 epochPay = 0;

        newSnapshot.endTime = block.timestamp;
        if (optionalDuration != 0 || currentSealedEpoch == 0) {
            newSnapshot.duration = optionalDuration;
        } else {
            newSnapshot.duration = block.timestamp.sub(epochSnapshots[currentSealedEpoch.sub(1)].endTime);
        }
        epochPay = epochPay.add(newSnapshot.duration);

        for (uint256 i = 0; i < stakerIDsArr.length; i++) {
            uint256 deactivatedTime =  stakers[stakerIDsArr[i]].deactivatedTime;
            if (deactivatedTime == 0 || block.timestamp < deactivatedTime) {
                uint256 power = stakers[stakerIDsArr[i]].stakeAmount + stakers[stakerIDsArr[i]].delegatedMe;
                newSnapshot.totalValidatingPower = newSnapshot.totalValidatingPower.add(power);
                newSnapshot.validators[stakerIDsArr[i]] = ValidatorMerit(
                    power,
                    stakers[stakerIDsArr[i]].stakeAmount,
                    stakers[stakerIDsArr[i]].delegatedMe
                );
            }
        }

        newSnapshot.epochFee = 2 ether;
        epochPay = epochPay.add(newSnapshot.epochFee);

        return epochPay;
    }
}
