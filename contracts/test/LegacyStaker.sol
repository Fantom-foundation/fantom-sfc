pragma solidity ^0.5.0;

import "./UnitTestStakers.sol";


contract LegacyStaker is UnitTestStakers {
    constructor (uint256 firstEpoch) public UnitTestStakers(firstEpoch) {
    }

    function createLegacyDelegation(uint256 to) external payable {
        address delegator = msg.sender;

        Delegation memory newDelegation;
        newDelegation.createdEpoch = currentEpoch();
        newDelegation.createdTime = block.timestamp;
        newDelegation.amount = msg.value;
        newDelegation.toStakerID = to;
        newDelegation.paidUntilEpoch = currentSealedEpoch;
        legacyDelegations[delegator] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(delegator, to, msg.value);
    }

    function prepareToWithdrawLegacyDelegation() external {
        address delegator = msg.sender;

        uint256 stakerID = legacyDelegations[delegator].toStakerID;
        _mayBurnRewardsOnDeactivation(true, stakerID, delegator, legacyDelegations[delegator].amount, legacyDelegations[delegator].amount);

        legacyDelegations[delegator].deactivatedEpoch = currentEpoch();
        legacyDelegations[delegator].deactivatedTime = block.timestamp;
        uint256 delegationAmount = legacyDelegations[delegator].amount;

        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegationAmount);
        }

        emit DeactivatedDelegation(delegator, stakerID);
    }

    function lockUpStake(uint256 lockDuration) external {
    }

    function lockUpDelegation(uint256 lockDuration, uint256 toStakerID) external {
    }
}

contract Factory {
    function createLegacyStaker(uint256 firstEpoch) external {
        new LegacyStaker(firstEpoch);
    }
}