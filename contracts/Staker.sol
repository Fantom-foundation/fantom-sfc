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

    uint256 public lastEpoch; // written by consensus outside
    mapping(uint256 => EpochSnapshot) public epochSnapshots; // written by consensus outside
    mapping(address => ValidationStake) public vStakers; // staker -> stake

    uint256 public vStakersLastIdx;
    uint256 public vStakersNum;
    uint256 public vStakeTotalAmount;
    uint256 public delegationsNum;
    uint256 public delegationsTotalAmount;

    mapping(address => Delegation[]) public delegations; // from -> delegations array

    /*
    Methods
    */

    event CreatedVStake(address indexed staker, uint256 amount);

    function createVStake() public payable {
        address staker = msg.sender;

        require(vStakers[staker].stakeAmount == 0); // staker doesn't exist yet
        require(msg.value >= minValidationStake);

        vStakers[staker].stakeAmount = msg.value;
        vStakers[staker].createdEpoch = lastEpoch;
        vStakers[staker].createdTime = block.timestamp;
        vStakers[staker].stakerIdx = ++vStakersLastIdx;

        vStakersNum++;
        vStakeTotalAmount += msg.value; // SS safeMath
        emit CreatedVStake(staker, msg.value);
    }

    event IncreasedVStake(address indexed staker, uint256 newAmount, uint256 diff);

    function increaseVStake() external payable {
        address staker = msg.sender;

        require(vStakers[staker].stakeAmount != 0); // staker exists
        uint256 newAmount = vStakers[staker].stakeAmount + msg.value; // SS safeMath
        vStakers[staker].stakeAmount = newAmount;
        vStakeTotalAmount += msg.value; // SS safeMath
        emit IncreasedVStake(staker, newAmount, msg.value);
    }

    event CreatedDelegation(address indexed from, address indexed to, uint256 amount, uint256 newEffectiveStake);

    function createDelegation(address to) external payable {
        address from = msg.sender;

        require(vStakers[to].stakeAmount != 0); // staker exist
        require(msg.value >= minDelegation);
        require((vStakers[to].stakeAmount * maxDelegatedMeRatio) / percentUnit >= vStakers[to].delegatedMe + msg.value); // SS safeMath
        uint256 i = delegations[from].length++;
        delegations[from][i].createdEpoch = lastEpoch;
        delegations[from][i].createdTime = block.timestamp;
        delegations[from][i].amount = msg.value;
        delegations[from][i].toStakerAddress = to;
        delegations[from][i].toStakerIdx = vStakers[to].stakerIdx;
        vStakers[to].delegatedMe += msg.value; // SS safeMath
        delegationsNum++;
        delegationsTotalAmount += msg.value;

        emit CreatedDelegation(from, to, msg.value, getEffectiveStake(to));
    }

    function getEffectiveStake(address staker) view internal returns (uint256) {
        return vStakers[staker].delegatedMe + vStakers[staker].stakeAmount; // SS safeMath
    }

    function calcTotalReward(address staker, uint256 epoch) view internal returns (uint256) {
        uint256 totalValidatingPower = epochSnapshots[epoch].totalValidatingPower;
        uint256 validatingPower = epochSnapshots[epoch].validators[staker].validatingPower;
        require(totalValidatingPower != 0);

        uint256 reward = 0;
        // base reward
        reward += (epochSnapshots[epoch].duration * validatingPower) / totalValidatingPower; // SS safeMath
        // fee reward
        reward += (epochSnapshots[epoch].epochFee * validatingPower) / totalValidatingPower; // SS safeMath
        return reward;
    }

    function calcValidatorReward(address staker, uint256 epoch) view internal returns (uint256) {
        uint256 fullReward = calcTotalReward(staker, epoch);

        uint256 stake = epochSnapshots[epoch].validators[staker].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[staker].delegatedMe;
        uint256 totalStake = stake + delegatedTotal; // SS safeMath
        uint256 weightedTotalStake = stake + (delegatedTotal * validatorCommission) / percentUnit; // SS safeMath
        return (fullReward * totalStake) / weightedTotalStake; // SS safeMath
    }

    function calcDelegatorReward(address staker, uint256 epoch, uint256 delegatedAmount) view internal returns (uint256) {
        uint256 fullReward = calcTotalReward(staker, epoch);

        uint256 stake = epochSnapshots[epoch].validators[staker].stakeAmount;
        uint256 delegatedTotal = epochSnapshots[epoch].validators[staker].delegatedMe;
        uint256 totalStake = stake + delegatedTotal; // SS safeMath
        uint256 weightedTotalStake = (delegatedAmount * (percentUnit - validatorCommission)) / percentUnit; // SS safeMath
        return (fullReward * totalStake) / weightedTotalStake; // SS safeMath
    }

    function withDefault(uint256 a, uint256 defaultA) pure private returns(uint256) {
        if (a == 0) {
            return defaultA;
        }
        return a;
    }

    event ClaimedDelegationReward(address indexed from, address indexed staker, uint256 reward, uint256 delegationIdx, uint256 fromEpoch, uint256 untilEpoch);

    function claimDelegationReward(uint256 dIdx, uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable from = msg.sender;

        require(delegations[from][dIdx].amount != 0); // delegation exists
        require(delegations[from][dIdx].deactivatedTime == 0); // not deactivated

        uint256 paidUntilEpoch = delegations[from][dIdx].paidUntilEpoch;
        uint256 delegatedAmount = delegations[from][dIdx].amount;
        uint256 stakerIdx = delegations[from][dIdx].toStakerIdx;
        address staker = delegations[from][dIdx].toStakerAddress;
        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch);
        uint256 untilEpoch = withDefault(_untilEpoch, lastEpoch);

        require(fromEpoch <= untilEpoch);
        require(untilEpoch <= lastEpoch);
        require(paidUntilEpoch < fromEpoch); // not paid yet

        uint256 reward = 0;
        for (uint256 e = fromEpoch; e <= untilEpoch; e++) {
            if (stakerIdx != epochSnapshots[e].validators[staker].stakerIdx) {
                // it's different staker, although the same address
                continue;
            }
            reward += calcDelegatorReward(staker, e, delegatedAmount); // SS safeMath
        }
        delegations[from][dIdx].paidUntilEpoch = untilEpoch;

        // It's important that we transfer after updating paidUntilEpoch (protection against Re-Entrancy)
        from.transfer(reward);

        emit ClaimedDelegationReward(from, staker, reward, dIdx, fromEpoch, untilEpoch);
    }

    event ClaimedValidatorReward(address indexed staker, uint256 reward, uint256 fromEpoch, uint256 untilEpoch);

    // may be already deactivated, but still allowed to withdraw old rewards
    function claimValidatorReward(uint256 _fromEpoch, uint256 _untilEpoch) external {
        address payable staker = msg.sender;
        require(vStakers[staker].stakeAmount != 0); // staker exists

        uint256 paidUntilEpoch = vStakers[staker].paidUntilEpoch;
        uint256 stakerIdx = vStakers[staker].stakerIdx;

        uint256 fromEpoch = withDefault(_fromEpoch, paidUntilEpoch);
        uint256 untilEpoch = withDefault(_untilEpoch, lastEpoch);

        require(fromEpoch <= untilEpoch);
        require(untilEpoch <= lastEpoch);
        require(paidUntilEpoch < fromEpoch); // not paid yet

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
        require(vStakers[staker].stakeAmount != 0); // staker exist
        require(vStakers[staker].deactivatedTime == 0); // not deactivated yet

        vStakers[staker].deactivatedEpoch = lastEpoch;
        vStakers[staker].deactivatedTime = block.timestamp;

        emit PreparedToWithdrawVStake(staker);
    }

    event WithdrawnVStake(address indexed staker, bool isCheater);

    function withdrawVStake() external {
        address payable staker = msg.sender;
        require(vStakers[staker].deactivatedTime != 0); // deactivated
        require(block.timestamp >= vStakers[staker].deactivatedTime + vStakeLockPeriodTime); // passed enough time // SS safeMath
        require(lastEpoch >= vStakers[staker].deactivatedEpoch + vStakeLockPeriodEpochs); // passed enough epochs // SS safeMath
        uint256 stake = vStakers[staker].stakeAmount;
        bool isCheater = vStakers[staker].isCheater;
        delete vStakers[staker];

        vStakersNum--;
        vStakeTotalAmount -= stake; // SS safeMath
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            staker.transfer(stake);
        }

        emit WithdrawnVStake(staker, isCheater);
    }

    event PreparedToWithdrawDelegation(address indexed from);

    // deactivate delegation, to be able to withdraw later
    function prepareToWithdrawDelegation(uint256 dIdx) external {
        address from = msg.sender;
        require(delegations[from][dIdx].amount != 0); // delegation exists
        require(delegations[from][dIdx].deactivatedTime == 0); // not deactivated yet

        delegations[from][dIdx].deactivatedEpoch = lastEpoch;
        delegations[from][dIdx].deactivatedTime = block.timestamp;
        address staker = delegations[from][dIdx].toStakerAddress;
        uint256 delegatedAmount = delegations[from][dIdx].amount;
        if (!isStakerErased(from, dIdx, staker)) {
            vStakers[staker].delegatedMe -= delegatedAmount; // SS safeMath
        }

        emit PreparedToWithdrawDelegation(from);
    }

    // return true if staker was overwritten with another staker (with the same address), or was withdrawn
    function isStakerErased(address deligator, uint256 dIdx, address staker) view internal returns(bool) {
        return vStakers[staker].stakerIdx != delegations[deligator][dIdx].toStakerIdx;
    }

    event WithdrawnDelegation(address indexed staker, bool isCheater);

    function withdrawDelegation(uint256 dIdx) external {
        address payable from = msg.sender;
        require(delegations[from][dIdx].deactivatedTime != 0); // deactivated
        require(block.timestamp >= delegations[from][dIdx].deactivatedTime + deleagtionLockPeriodTime); // passed enough time // SS safeMath
        require(lastEpoch >= delegations[from][dIdx].deactivatedEpoch + deleagtionLockPeriodEpochs); // passed enough epochs // SS safeMath
        address staker = delegations[from][dIdx].toStakerAddress;
        bool isCheater = vStakers[staker].isCheater;
        uint256 delegatedAmount = delegations[from][dIdx].amount;

        _removeDelegation(from, dIdx);

        delegationsNum--;
        delegationsTotalAmount -= delegatedAmount; // SS safeMath
        // It's important that we transfer after erasing (protection against Re-Entrancy)
        if (isCheater == false) {
            from.transfer(delegatedAmount);
        }

        emit WithdrawnDelegation(staker, isCheater);
    }

    // free the storage
    function _removeDelegation(address delegator, uint256 dIdx) private {
        // Move the last element to the deleted slot
        uint256 len = delegations[delegator].length;
        delegations[delegator][dIdx] = delegations[delegator][len - 1]; // SS safeMath
        len--;
        delegations[delegator].length = len;
        if (len == 0) {
            delete delegations[delegator];
        }
    }
}

contract TestStakers is Stakers {
    address[] public validatorAddresses;

    constructor (uint256 firstEpoch) public {
        lastEpoch = firstEpoch;
    }

    function _markValidationStakeAsCheater(address validatorAddress, bool status) external {
        if (vStakers[validatorAddress].stakerIdx != 0x0) {
            vStakers[validatorAddress].isCheater = status;
        }
    }

    function createVStake() public payable {
        validatorAddresses.push(msg.sender); // SS Check existing?
        super.createVStake();
    }

    function _makeEpochSnapshots() external {
        EpochSnapshot storage newSnapshots = epochSnapshots[lastEpoch];

        newSnapshots.endTime = block.timestamp;
        newSnapshots.duration = block.timestamp.sub(epochSnapshots[lastEpoch].endTime);
        for (uint256 i = 0; i < validatorAddresses.length; i++) {
            if (block.timestamp < vStakers[validatorAddresses[i]].deactivatedTime) {
                uint256 power = 0.5 ether;
                newSnapshots.totalValidatingPower = newSnapshots.totalValidatingPower.add(power);
                newSnapshots.validators[validatorAddresses[i]] = ValidatorMerit(
                    power,
                    vStakers[validatorAddresses[i]].stakeAmount,
                    vStakers[validatorAddresses[i]].delegatedMe,
                    vStakers[validatorAddresses[i]].stakerIdx
                );
            }
        }

        newSnapshots.epochFee = 2 ether;

        lastEpoch++;
    }
}
