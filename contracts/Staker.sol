pragma solidity >=0.5.0 <=0.5.3;

import "./SafeMath.sol";

contract Stakers {
    using SafeMath for uint256;

    uint256 public constant minValidationStake = 1e18;
    uint256 public constant minValidationStakeIncrease = 1e18;
    uint256 public constant minDelegation = 1e18;

    uint256 public constant percentUnit = 1000000;
    uint256 public constant maxDelegatedMeRatio = 15 * percentUnit; // 1500%
    uint256 public constant validatorCommission = (15 * percentUnit) / 100; // 15%

    uint256 public constant contractCommission = (30 * percentUnit) / 100; // 30%

    uint256 public constant vStakeLockPeriodTime = 60 * 60 * 24 * 7; // 7 days
    uint256 public constant vStakeLockPeriodEpochs = 3;
    uint256 public constant deleagtionLockPeriodTime = 60 * 60 * 24 * 7; // 7 days
    uint256 public constant deleagtionLockPeriodEpochs = 3;

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
        bool isCheater; // written by consensus outside

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
    mapping(uint256 => ValidationStake) public vStakers; // stakerID -> stake
    mapping(address => uint256) public vStakerIDs; // staker address -> stakerID

    uint256 public vStakersLastID;
    uint256 public vStakersNum;
    uint256 public vStakeTotalAmount;
    uint256 public delegationsNum;
    uint256 public delegationsTotalAmount;

    mapping(address => Delegation) public delegations; // delegationID -> delegation

    /*
    Methods
    */

    function getEpochValidator(uint256 e, uint256 v) external view returns (uint256, uint256, uint256) {
        return (epochSnapshots[e].validators[v].validatingPower,
                epochSnapshots[e].validators[v].stakeAmount,
                epochSnapshots[e].validators[v].delegatedMe);
    }

    function currentEpoch() public view returns (uint256) {
        return currentSealedEpoch + 1;
    }

    event CreatedVStake(uint256 indexed stakerID, address indexed stakerAddress, uint256 amount);

    function createVStake() external payable {
        implCreateVStake();
    }

    function implCreateVStake() internal {
        address staker = msg.sender;

        require(vStakerIDs[staker] == 0, "staker already exists");
        require(delegations[staker].amount == 0, "already delegating");
        require(msg.value >= minValidationStake, "insufficient amount");

        uint256 stakerID = ++vStakersLastID;
        vStakerIDs[staker] = stakerID;
        vStakers[stakerID].stakeAmount = msg.value;
        vStakers[stakerID].createdEpoch = currentEpoch();
        vStakers[stakerID].createdTime = block.timestamp;
        vStakers[stakerID].stakerAddress = staker;

        vStakersNum++;
        vStakeTotalAmount = vStakeTotalAmount.add(msg.value);
        emit CreatedVStake(stakerID, staker, msg.value);
    }

    event IncreasedVStake(uint256 indexed stakerID, uint256 newAmount, uint256 diff);

    function increaseVStake() external payable {
        address staker = msg.sender;
        uint256 stakerID = vStakerIDs[staker];

        require(msg.value >= minValidationStakeIncrease, "insufficient amount");
        require(vStakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(vStakers[stakerID].deactivatedTime == 0, "staker shouldn't be deactivated yet");
        require(vStakers[stakerID].isCheater == false, "staker shouldn't be cheater");

        uint256 newAmount = vStakers[stakerID].stakeAmount.add(msg.value);
        vStakers[stakerID].stakeAmount = newAmount;
        vStakeTotalAmount = vStakeTotalAmount.add(msg.value);
        emit IncreasedVStake(stakerID, newAmount, msg.value);
    }

    event CreatedDelegation(address indexed from, uint256 indexed toStakerID, uint256 amount);

    function createDelegation(uint256 to) external payable {
        address from = msg.sender;

        require(vStakers[to].stakeAmount != 0, "staker doesn't exist");
        require(vStakers[to].isCheater == false, "staker shouldn't be cheater");
        require(msg.value >= minDelegation, "insufficient amount for delegation");
        require(delegations[from].amount == 0, "delegation already exists");
        require(vStakerIDs[from] == 0, "already staking");
        require((vStakers[to].stakeAmount.mul(maxDelegatedMeRatio)).div(percentUnit) >= vStakers[to].delegatedMe.add(msg.value), "staker's limit is exceeded");

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        delegations[from] = newDelegation;

        vStakers[to].delegatedMe = vStakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(from, to, msg.value);
    }

    function calcTotalReward(uint256 stakerID, uint256 epoch) view internal returns (uint256) {
        uint256 totalValidatingPower = epochSnapshots[epoch].totalValidatingPower;
        uint256 validatingPower = epochSnapshots[epoch].validators[stakerID].validatingPower;
        require(totalValidatingPower != 0, "total validating power can't be zero");

        // base reward
        uint256 reward = epochSnapshots[epoch].duration.mul(validatingPower).div(totalValidatingPower);
        // fee reward except contractCommission
        uint256 feeReward = epochSnapshots[epoch].epochFee.mul(validatingPower).div(totalValidatingPower);
        feeReward = feeReward.mul(percentUnit - contractCommission).div(percentUnit);

        return reward.add(feeReward);
    }

    function calcValidatorReward(uint256 stakerID, uint256 epoch) view internal returns (uint256) {
        uint256 fullReward = calcTotalReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        uint256 weightedTotalStake = stake.add((delegatedTotal.mul(validatorCommission)).div(percentUnit));
        return (fullReward.mul(weightedTotalStake)).div(totalStake);
    }

    function calcDelegatorReward(uint256 stakerID, uint256 epoch, uint256 delegatedAmount) view internal returns (uint256) {
        uint256 fullReward = calcTotalReward(stakerID, epoch);

        uint256 stake = epochSnapshots[epoch].validators[stakerID].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[stakerID].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        uint256 weightedTotalStake = (delegatedAmount.mul(percentUnit.sub(validatorCommission))).div(percentUnit);
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
            reward += calcDelegatorReward(stakerID, e, delegatedAmount); // SS safeMath
        }
        delegations[from].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        msg.sender.transfer(reward);

        emit ClaimedDelegationReward(from, stakerID, reward, fromEpoch, untilEpoch);
    }

    event ClaimedValidatorReward(uint256 indexed stakerID, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // may be already deactivated, but still allowed to withdraw old rewards
    function claimValidatorReward(uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable staker = msg.sender;
        uint256 stakerID = vStakerIDs[staker];
        require(vStakers[stakerID].stakeAmount != 0, "staker doesn't exist");

        uint256 paidUntilEpoch = vStakers[stakerID].paidUntilEpoch;

        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch + 1);
        uint256 untilEpoch = withDefault(_untilEpoch, currentSealedEpoch);

        require(paidUntilEpoch < fromEpoch, "epoch is already paid");
        require(fromEpoch <= untilEpoch, "invalid fromEpoch");
        require(untilEpoch <= currentSealedEpoch, "invalid untilEpoch");

        uint256 reward = 0;
        for (uint256 e = fromEpoch; e <= untilEpoch; e++) {
            reward += calcValidatorReward(stakerID, e);
        }
        vStakers[stakerID].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        staker.transfer(reward);

        emit ClaimedValidatorReward(stakerID, reward, fromEpoch, untilEpoch);
    }

    event PreparedToWithdrawVStake(uint256 indexed stakerID);

    // deactivate stake, to be able to withdraw later
    function prepareToWithdrawVStake() external {
        address staker = msg.sender;
        uint256 stakerID = vStakerIDs[staker];
        require(vStakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        require(vStakers[stakerID].deactivatedTime == 0, "staker shouldn't be deactivated yet");

        vStakers[stakerID].deactivatedEpoch = currentEpoch();
        vStakers[stakerID].deactivatedTime = block.timestamp;

        emit PreparedToWithdrawVStake(stakerID);
    }

    event WithdrawnVStake(uint256 indexed stakerID, bool isCheater);

    function withdrawVStake() external {
        address payable staker = msg.sender;
        uint256 stakerID = vStakerIDs[staker];
        require(vStakers[stakerID].deactivatedTime != 0, "staker wasn't deactivated");
        require(block.timestamp >= vStakers[stakerID].deactivatedTime + vStakeLockPeriodTime, "not enough time passed");
        require(currentEpoch() >= vStakers[stakerID].deactivatedEpoch + vStakeLockPeriodEpochs, "not enough epochs passed");

        uint256 stake = vStakers[stakerID].stakeAmount;
        bool isCheater = vStakers[stakerID].isCheater;
        delete vStakers[stakerID];
        delete vStakerIDs[staker];

        vStakersNum--;
        vStakeTotalAmount = vStakeTotalAmount.sub(stake);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            staker.transfer(stake);
        }

        emit WithdrawnVStake(stakerID, isCheater);
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
        if (vStakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            vStakers[stakerID].delegatedMe = vStakers[stakerID].delegatedMe.sub(delegatedAmount);
        }

        emit PreparedToWithdrawDelegation(from);
    }

    event WithdrawnDelegation(uint256 indexed stakerID, bool isCheater);

    function withdrawDelegation() external {
        address payable from = msg.sender;
        require(delegations[from].deactivatedTime != 0, "delegation wasn't deactivated");
        require(block.timestamp >= delegations[from].deactivatedTime + deleagtionLockPeriodTime, "not enough time passed");
        require(currentEpoch() >= delegations[from].deactivatedEpoch + deleagtionLockPeriodEpochs, "not enough epochs passed");
        uint256 stakerID = delegations[from].toStakerID;
        bool isCheater = vStakers[stakerID].isCheater;
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
    uint256[] public stakerIDsArr;

    constructor (uint256 firstEpoch) public {
        currentSealedEpoch = firstEpoch;
    }

    function _markValidationStakeAsCheater(uint256 stakerID, bool status) external {
        if (vStakers[stakerID].stakeAmount != 0) {
            vStakers[stakerID].isCheater = status;
        }
    }

    function _createVStake() external payable {
        stakerIDsArr.push(vStakersLastID + 1); // SS Check existing?
        super.implCreateVStake();
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
            uint256 deactivatedTime =  vStakers[stakerIDsArr[i]].deactivatedTime;
            if (deactivatedTime == 0 || block.timestamp < deactivatedTime) {
                uint256 power = i.mul(2).add(1).mul(0.5 ether);
                newSnapshot.totalValidatingPower = newSnapshot.totalValidatingPower.add(power);
                newSnapshot.validators[stakerIDsArr[i]] = ValidatorMerit(
                    power,
                    vStakers[stakerIDsArr[i]].stakeAmount,
                    vStakers[stakerIDsArr[i]].delegatedMe
                );
            }
        }

        newSnapshot.epochFee = 2 ether;
        epochPay = epochPay.add(newSnapshot.epochFee);

        return epochPay;
    }

    function _calcTotalReward(uint256 stakerID, uint256 epoch) view external returns (uint256) {
        return super.calcTotalReward(stakerID, epoch);
    }

    function _calcValidatorReward(uint256 stakerID, uint256 epoch) view external returns (uint256) {
        return super.calcValidatorReward(stakerID, epoch);
    }

    function _calcDelegatorReward(uint256 stakerID, uint256 epoch, uint256 delegatedAmount) view external returns (uint256) {
        return super.calcDelegatorReward(stakerID, epoch, delegatedAmount);
    }
}
