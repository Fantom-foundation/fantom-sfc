pragma solidity ^0.5.0;

import "../sfc/Staker.sol";

contract TestStakers is Stakers {
    function stakeLockPeriodTime() public pure returns (uint256) {
        return 1 * 60;
    }

    function delegationLockPeriodTime() public pure returns (uint256) {
        return 1 * 60;
    }
}

contract UnitTestStakers is Stakers {
    struct DelegationID {
        address delegator;
        uint256 stakerID;
    }

    uint256[] public stakerIDsArr;
    DelegationID[] public delegationIDsArr;

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
        stakerIDsArr.push(stakersLastID + 1);
        super.createStake("");
    }

    function createDelegation(uint256 to) public payable {
        delegationIDsArr.push(DelegationID(msg.sender, to));
        super._createDelegation(msg.sender, to);
    }

    function makeEpochSnapshots(uint256 optionalDuration, bool addTxPower) external returns (uint256) {
        return _makeEpochSnapshots(optionalDuration, addTxPower);
    }

    function _makeEpochSnapshots(uint256 optionalDuration, bool addTxPower) internal returns (uint256) {
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
            uint256 stakerID = stakerIDsArr[i];
            uint256 deactivatedTime = stakers[stakerID].deactivatedTime;
            if (deactivatedTime == 0 || block.timestamp < deactivatedTime) {
                uint256 basePower = stakers[stakerID].stakeAmount + stakers[stakerID].delegatedMe;
                uint256 txPower = 0;
                if (addTxPower) {
                    txPower = 1000 * i + basePower;
                }
                newSnapshot.totalBaseRewardWeight += basePower;
                newSnapshot.totalTxRewardWeight += txPower;
                newSnapshot.validators[stakerID] = ValidatorMerit(
                    stakers[stakerID].stakeAmount,
                    stakers[stakerID].delegatedMe,
                    basePower,
                    txPower
                );
            }
        }

        newSnapshot.baseRewardPerSecond = _baseRewardPerSecond();
        newSnapshot.epochFee = 2 * 1e18;
        epochPay += newSnapshot.epochFee;

        return epochPay;
    }

    function calcRawValidatorEpochReward(uint256 stakerID, uint256 epoch) external view returns (uint256) {
        return _calcRawValidatorEpochReward(stakerID, epoch);
    }

    function calcValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 commission) external view returns (uint256) {
        _RewardsSet memory rewards = _calcValidatorEpochReward(stakerID, epoch, commission, 0);
        return rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
    }

    function calcValidatorLockupRewards(uint256 stakerID, uint256 _fromEpoch, uint256 maxEpochs) external view returns (uint256 unlockedReward, uint256 lockupBaseReward, uint256 lockupExtraReward, uint256 burntReward, uint256 fromEpoch, uint256 untilEpoch) {
        _RewardsSet memory rewards;
        (rewards, fromEpoch, untilEpoch) = _calcValidatorLockupRewards(stakerID, _fromEpoch, maxEpochs, false);
        return (rewards.unlockedReward, rewards.lockupBaseReward, rewards.lockupExtraReward, rewards.burntReward, fromEpoch, untilEpoch);
    }

    function calcDelegationLockupRewards(address addr, uint256 toStakerID, uint256 _fromEpoch, uint256 maxEpochs) external view returns (uint256 unlockedReward, uint256 lockupBaseReward, uint256 lockupExtraReward, uint256 burntReward, uint256 fromEpoch, uint256 untilEpoch) {
        _RewardsSet memory rewards;
        (rewards, fromEpoch, untilEpoch) = _calcDelegationLockupRewards(addr, toStakerID, _fromEpoch, maxEpochs, false);
        return (rewards.unlockedReward, rewards.lockupBaseReward, rewards.lockupExtraReward, rewards.burntReward, fromEpoch, untilEpoch);
    }

    function calcDelegationEpochReward(address delegator, uint256 toStakerID, uint256 epoch, uint256, uint256 commission) external view returns (uint256) {
        _RewardsSet memory rewards = _calcDelegationEpochReward(delegator, toStakerID, epoch, commission, 0);
        return rewards.unlockedReward + rewards.lockupBaseReward + rewards.lockupExtraReward;
    }

    function calcDelegationPenalty(address delegator, uint256 toStakerID, uint256 withdrawalAmount) external view returns (uint256) {
        return _calcDelegationPenalty(delegator, toStakerID, withdrawalAmount, delegations[delegator][toStakerID].amount);
    }

    function discardValidatorRewards() public {
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        stakers[stakerID].paidUntilEpoch = currentSealedEpoch;
    }

    function discardDelegationRewards(uint256 toStakerID) public {
        if (legacyDelegations[msg.sender].amount != 0) {
            legacyDelegations[msg.sender].paidUntilEpoch = currentSealedEpoch;
        } else if (delegations[msg.sender][toStakerID].amount != 0) {
            delegations[msg.sender][toStakerID].paidUntilEpoch = currentSealedEpoch;
        } else {
            revert("delegation doesn't exist");
        }
    }
}
