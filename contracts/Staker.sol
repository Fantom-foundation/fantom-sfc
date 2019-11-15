pragma solidity >=0.5.0 <=0.5.3;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract Stakers {
    using SafeMath for uint256;

    uint256 public constant minValidationStake = 1 ether;
    uint256 public constant minDelegation = 1 ether;

    uint256 public constant percentUnit = 1000000;
    uint256 public constant maxDelegatedMeRatio = 15 * percentUnit; // 1500%
    uint256 public constant validatorCommission = (15 * percentUnit) / 100; // 15%

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
        address toStakerAddress;
        uint256 toStakerIdx;
    }

    struct ValidationStake {
        bool isCheater; // written by consensus outside
        uint256 stakerIdx;

        uint256 createdEpoch;
        uint256 createdTime;
        uint256 deactivatedEpoch;
        uint256 deactivatedTime;

        uint256 stakeAmount;
        uint256 paidUntilEpoch;

        uint256 delegatedMe;
    }

    struct ValidatorMerit {
        uint256 validatingPower;
        uint256 stakeAmount;
        uint256 delegatedMe;
        uint256 stakerIdx;
    }

    struct EpochSnapshot {
        mapping(address => ValidatorMerit) validators;

        uint256 endTime;
        uint256 duration;
        uint256 epochFee;
        uint256 totalValidatingPower;
    }

    uint256 public currentSealedEpoch; // written by consensus outside
    mapping(uint256 => EpochSnapshot) public epochSnapshots; // written by consensus outside
    mapping(address => ValidationStake) public vStakers; // staker -> stake

    uint256 public vStakersLastIdx;
    uint256 public vStakersNum;
    uint256 public vStakeTotalAmount;
    uint256 public delegationsNum;
    uint256 public delegationsTotalAmount;

    mapping(address => Delegation) public delegations; // from -> delegation

    /*
    Methods
    */

    function currentEpoch() public view returns (uint256) {
        return currentSealedEpoch + 1;
    }

    event CreatedVStake(address indexed staker, uint256 amount);

    function createVStake() public payable {
        address staker = msg.sender;

        require(vStakers[staker].stakeAmount == 0, "staker already exists");
        require(msg.value >= minValidationStake, "insufficient amount for staking");

        vStakers[staker].stakeAmount = msg.value;
        vStakers[staker].createdEpoch = currentEpoch();
        vStakers[staker].createdTime = block.timestamp;
        vStakers[staker].stakerIdx = ++vStakersLastIdx;

        vStakersNum++;
        vStakeTotalAmount = vStakeTotalAmount.add(msg.value);
        emit CreatedVStake(staker, msg.value);
    }

    event IncreasedVStake(address indexed staker, uint256 newAmount, uint256 diff);

    function increaseVStake() external payable {
        address staker = msg.sender;

        require(vStakers[staker].stakeAmount != 0, "staker wasn't created");
        uint256 newAmount = vStakers[staker].stakeAmount.add(msg.value);
        vStakers[staker].stakeAmount = newAmount;
        vStakeTotalAmount = vStakeTotalAmount.add(msg.value);
        emit IncreasedVStake(staker, newAmount, msg.value);
    }

    event CreatedDelegation(address indexed from, address indexed to, uint256 amount, uint256 newEffectiveStake);

    function createDelegation(address to) external payable {
        address from = msg.sender;

        require(vStakers[to].stakeAmount != 0, "staker wasn't created");
        require(msg.value >= minDelegation, "insufficient amount for delegation");
        require(delegations[from].createdTime == 0, "delegate already exists");
        require((vStakers[to].stakeAmount.mul(maxDelegatedMeRatio)).div(percentUnit) >= vStakers[to].delegatedMe.add(msg.value), "delegated limit is exceeded");
        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerAddress = to;
        newDelegation.toStakerIdx = vStakers[to].stakerIdx;
        delegations[from] = newDelegation;

        vStakers[to].delegatedMe = vStakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        uint256 effectiveStake = vStakers[to].delegatedMe.add(vStakers[to].stakeAmount);
        emit CreatedDelegation(from, to, msg.value, effectiveStake);
    }

    function calcTotalReward(address staker, uint256 epoch) view internal returns (uint256) {
        uint256 totalValidatingPower = epochSnapshots[epoch].totalValidatingPower;
        uint256 validatingPower = epochSnapshots[epoch].validators[staker].validatingPower;
        require(totalValidatingPower != 0, "total validating power can't be zero");

        uint256 reward = 0;
        // base reward
        reward = reward.add(epochSnapshots[epoch].duration.mul(validatingPower).div(totalValidatingPower));
        // fee reward
        reward = reward.add(epochSnapshots[epoch].epochFee.mul(validatingPower).div(totalValidatingPower));
        return reward;
    }

    function calcValidatorReward(address staker, uint256 epoch) view internal returns (uint256) {
        uint256 fullReward = calcTotalReward(staker, epoch);

        uint256 stake = epochSnapshots[epoch].validators[staker].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[staker].delegatedMe;
        uint256 totalStake = stake.add(delegatedTotal);
        uint256 weightedTotalStake = stake.add((delegatedTotal.mul(validatorCommission)).div(percentUnit));
        return (fullReward.mul(weightedTotalStake)).div(totalStake);
    }

    function calcDelegatorReward(address staker, uint256 epoch, uint256 delegatedAmount) view internal returns (uint256) {
        uint256 fullReward = calcTotalReward(staker, epoch);

        uint256 stake = epochSnapshots[epoch].validators[staker].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[staker].delegatedMe;
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

    event ClaimedDelegationReward(address indexed from, address indexed staker, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    function claimDelegationReward(uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable from = msg.sender;

        require(delegations[from].amount != 0, "delegation doesn't exists");
        require(delegations[from].deactivatedTime == 0, "delegation shouldn't be deactivated yet");

        uint256 paidUntilEpoch = delegations[from].paidUntilEpoch;
        uint256 delegatedAmount = delegations[from].amount;
        uint256 stakerIdx = delegations[from].toStakerIdx;
        address stakerAddress = delegations[from].toStakerAddress;
        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch + 1);
        uint256 untilEpoch = withDefault(_untilEpoch, currentSealedEpoch);

        require(fromEpoch <= untilEpoch, "invalid fromEpoch");
        require(untilEpoch <= currentSealedEpoch, "invalid untilEpoch");
        require(paidUntilEpoch < fromEpoch, "epoch is already paid");

        uint256 reward = 0;
        for (uint256 e = fromEpoch; e <= untilEpoch; e++) {
            if (stakerIdx != epochSnapshots[e].validators[stakerAddress].stakerIdx) {
                // it's different staker, although the same address
                continue;
            }
            reward += calcDelegatorReward(stakerAddress, e, delegatedAmount); // SS safeMath
        }
        delegations[from].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        msg.sender.transfer(reward);

        emit ClaimedDelegationReward(from, stakerAddress, reward, fromEpoch, untilEpoch);
    }

    event ClaimedValidatorReward(address indexed staker, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // may be already deactivated, but still allowed to withdraw old rewards
    function claimValidatorReward(uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable staker = msg.sender;
        require(vStakers[staker].stakeAmount != 0, "staker doesn't exists");

        uint256 paidUntilEpoch = vStakers[staker].paidUntilEpoch;
        uint256 stakerIdx = vStakers[staker].stakerIdx;

        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch + 1);
        uint256 untilEpoch = withDefault(_untilEpoch, currentSealedEpoch);

        require(fromEpoch <= untilEpoch, "invalid fromEpoch");
        require(untilEpoch <= currentSealedEpoch, "invalid untilEpoch");
        require(paidUntilEpoch < fromEpoch, "epoch is already paid");

        uint256 reward = 0;
        for (uint256 e = fromEpoch; e <= untilEpoch; e++) {
            if (stakerIdx != epochSnapshots[e].validators[staker].stakerIdx) {
                // it's different staker, although the same address
                continue;
            }

            reward += calcValidatorReward(staker, e);
        }
        vStakers[staker].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        staker.transfer(reward);

        emit ClaimedValidatorReward(staker, reward, fromEpoch, untilEpoch);
    }

    event PreparedToWithdrawVStake(address indexed staker);

    // deactivate stake, to be able to withdraw later
    function prepareToWithdrawVStake() external {
        address staker = msg.sender;
        require(vStakers[staker].stakeAmount != 0, "staker doesn't exists");
        require(vStakers[staker].deactivatedTime == 0, "staker shouldn't be deactivated yet");

        vStakers[staker].deactivatedEpoch = currentEpoch();
        vStakers[staker].deactivatedTime = block.timestamp;

        emit PreparedToWithdrawVStake(staker);
    }

    event WithdrawnVStake(address indexed staker, bool isCheater);

    function withdrawVStake() external {
        address payable staker = msg.sender;
        require(vStakers[staker].deactivatedTime != 0, "staker wasn't deactivated");
        require(block.timestamp >= vStakers[staker].deactivatedTime.add(vStakeLockPeriodTime), "not enough time passed");
        require(currentEpoch() >= vStakers[staker].deactivatedEpoch.add(vStakeLockPeriodEpochs), "not enough epochs passed");
        uint256 stake = vStakers[staker].stakeAmount;
        bool isCheater = vStakers[staker].isCheater;
        delete vStakers[staker];

        vStakersNum--;
        vStakeTotalAmount = vStakeTotalAmount.sub(stake);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            staker.transfer(stake);
        }

        emit WithdrawnVStake(staker, isCheater);
    }

    event PreparedToWithdrawDelegation(address indexed from);

    // deactivate delegation, to be able to withdraw later
    function prepareToWithdrawDelegation() external {
        address from = msg.sender;
        require(delegations[from].amount != 0, "delegation doesn't exists");
        require(delegations[from].deactivatedTime == 0, "delegation shouldn't be deactivated yet");

        delegations[from].deactivatedEpoch = currentEpoch();
        delegations[from].deactivatedTime = block.timestamp;
        address staker = delegations[from].toStakerAddress;
        uint256 delegatedAmount = delegations[from].amount;
        if (!isStakerErased(from, staker)) {
            vStakers[staker].delegatedMe = vStakers[staker].delegatedMe.sub(delegatedAmount);
        }

        emit PreparedToWithdrawDelegation(from);
    }

    // return true if staker was overwritten with another staker (with the same address), or was withdrawn
    function isStakerErased(address deligator, address staker) view internal returns(bool) {
        return vStakers[staker].stakerIdx != delegations[deligator].toStakerIdx;
    }

    event WithdrawnDelegation(address indexed staker, bool isCheater);

    function withdrawDelegation() external {
        address payable from = msg.sender;
        require(delegations[from].deactivatedTime != 0, "delegation wasn't deactivated");
        require(block.timestamp >= delegations[from].deactivatedTime.add(deleagtionLockPeriodTime), "not enough time passed");
        require(currentEpoch() >= delegations[from].deactivatedEpoch.add(deleagtionLockPeriodEpochs), "not enough epochs passed");
        address staker = delegations[from].toStakerAddress;
        bool isCheater = vStakers[staker].isCheater;
        uint256 delegatedAmount = delegations[from].amount;
        delete delegations[from];

        delegationsNum--;
        delegationsTotalAmount = delegationsTotalAmount.sub(delegatedAmount);
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            from.transfer(delegatedAmount);
        }

        emit WithdrawnDelegation(staker, isCheater);
    }
}

contract TestStakers is Stakers {
    address[] public validatorAddresses;

    constructor (uint256 firstEpoch) public {
        currentSealedEpoch = firstEpoch;
    }

    function _markValidationStakeAsCheater(address validatorAddress, bool status) external {
        if (vStakers[validatorAddress].stakerIdx != 0x0) {
            vStakers[validatorAddress].isCheater = status;
        }
    }

    function _createVStake() external payable {
        validatorAddresses.push(msg.sender); // SS Check existing?
        super.createVStake();
    }

    function _makeEpochSnapshots(uint256 optionalDuration) external returns(uint256) {
        EpochSnapshot storage newSnapshot = epochSnapshots[currentSealedEpoch];
        uint256 epochPay = 0;

        newSnapshot.endTime = block.timestamp;
        if (optionalDuration != 0 || currentSealedEpoch == 0) {
            newSnapshot.duration = optionalDuration;
        } else {
            newSnapshot.duration = block.timestamp.sub(epochSnapshots[currentSealedEpoch.sub(1)].endTime);
        }
        epochPay = epochPay.add(newSnapshot.duration);

        for (uint256 i = 0; i < validatorAddresses.length; i++) {
            uint256 deactivatedTime =  vStakers[validatorAddresses[i]].deactivatedTime;
            if (deactivatedTime == 0 || block.timestamp < deactivatedTime) {
                uint256 power = i.mul(2).add(1).mul(0.5 ether);
                newSnapshot.totalValidatingPower = newSnapshot.totalValidatingPower.add(power);
                newSnapshot.validators[validatorAddresses[i]] = ValidatorMerit(
                    power,
                    vStakers[validatorAddresses[i]].stakeAmount,
                    vStakers[validatorAddresses[i]].delegatedMe,
                    vStakers[validatorAddresses[i]].stakerIdx
                );
            }
        }

        newSnapshot.epochFee = 2 ether;
        epochPay = epochPay.add(newSnapshot.epochFee);

        currentSealedEpoch++;

        return epochPay;
    }

    function _calcTotalReward(address staker, uint256 epoch) view external returns (uint256) {
        return super.calcTotalReward(staker, epoch);
    }

    function _calcValidatorReward(address staker, uint256 epoch) view external returns (uint256) {
        return super.calcValidatorReward(staker, epoch);
    }

    function _calcDelegatorReward(address staker, uint256 epoch, uint256 delegatedAmount) view external returns (uint256) {
        return super.calcDelegatorReward(staker, epoch, delegatedAmount);
    }
}
