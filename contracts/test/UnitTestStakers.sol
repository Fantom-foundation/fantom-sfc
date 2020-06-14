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
        super.createDelegation(to);
    }

    function makeEpochSnapshots(uint256 optionalDuration) external returns(uint256) {
        return _makeEpochSnapshots(optionalDuration, true);
    }

    function makeEpochSnapshots(uint256 optionalDuration, bool addTxPower) external returns(uint256) {
        return _makeEpochSnapshots(optionalDuration, addTxPower);
    }
    function _makeEpochSnapshots(uint256 optionalDuration, bool addTxPower) internal returns(uint256) {
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
                // newSnapshot.stakeTotalAmount += stakers[stakerID].stakeAmount; // or += basePower ?
                // newSnapshot.delegationsTotalAmount += stakers[stakerID].delegatedMe;
                // newSnapshot.totalSupply += (basePower + txPower);
                if (firstLockedUpEpoch > 0 &&
                    firstLockedUpEpoch <= currentSealedEpoch &&
                    lockedStakes[stakerID].fromEpoch <= currentSealedEpoch &&
                    lockedStakes[stakerID].endTime >= newSnapshot.endTime) {
                    newSnapshot.totalLockedAmount += stakers[stakerID].stakeAmount;
                }
                newSnapshot.validators[stakerID] = ValidatorMerit(
                    stakers[stakerID].stakeAmount,
                    stakers[stakerID].delegatedMe,
                    basePower,
                    txPower
                );
            }
        }

        if (firstLockedUpEpoch > 0) {
            for (uint256 i = 0; i < delegationIDsArr.length; i++) {
                address delegator = delegationIDsArr[i].delegator;
                uint256 stakerID = delegationIDsArr[i].stakerID;
                if (lockedDelegations[delegator][stakerID].fromEpoch >= currentSealedEpoch &&
                    lockedDelegations[delegator][stakerID].endTime >= newSnapshot.endTime) {
                    newSnapshot.totalLockedAmount += delegations_v2[delegator][stakerID].amount;
                }
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

    function calcLockedUpReward(uint256 amount, uint256 epoch) external view returns (uint256) {
        return _calcLockedUpReward(amount, epoch);
    }

    function calcValidatorEpochReward(uint256 stakerID, uint256 epoch, uint256 commission) external view returns (uint256) {
        return _calcValidatorEpochReward(stakerID, epoch, commission);
    }

    function calcDelegationEpochReward(uint256 stakerID, uint256 epoch, uint256 delegationAmount, uint256 commission, address delegator) external view returns (uint256) {
        return _calcDelegationEpochReward(stakerID, epoch, delegationAmount, commission, delegator);
    }

    function discardValidatorRewards() public {
        uint256 stakerID = _sfcAddressToStakerID(msg.sender);
        require(stakers[stakerID].stakeAmount != 0, "staker doesn't exist");
        stakers[stakerID].paidUntilEpoch = currentSealedEpoch;
    }

    function discardDelegationRewards(uint256 stakerID) public {
        if (delegations[msg.sender].amount != 0) {
            delegations[msg.sender].paidUntilEpoch = currentSealedEpoch;
        } else if (delegations_v2[msg.sender][stakerID].amount != 0) {
            delegations_v2[msg.sender][stakerID].paidUntilEpoch = currentSealedEpoch;
        } else {
            revert("delegation doesn't exist");
        }
    }

    function rewardsAllowed() public view returns (bool) {
        return true;
    }
}