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
        delegations[delegator] = newDelegation;

        stakers[to].delegatedMe = stakers[to].delegatedMe.add(msg.value);
        delegationsNum++;
        delegationsTotalAmount = delegationsTotalAmount.add(msg.value);

        emit CreatedDelegation(delegator, to, msg.value);
    }

    function prepareToWithdrawLegacyDelegation() external {
        address delegator = msg.sender;

        uint256 stakerID = delegations[delegator].toStakerID;
        _mayBurnRewardsOnDeactivation(true, stakerID, delegator, delegations[delegator].amount, delegations[delegator].amount);

        delegations[delegator].deactivatedEpoch = currentEpoch();
        delegations[delegator].deactivatedTime = block.timestamp;
        uint256 delegationAmount = delegations[delegator].amount;

        if (stakers[stakerID].stakeAmount != 0) {
            // if staker haven't withdrawn
            stakers[stakerID].delegatedMe = stakers[stakerID].delegatedMe.sub(delegationAmount);
        }

        emit DeactivatedDelegation(delegator, stakerID);
    }
}

contract Factory {
    function createLegacyStaker(uint256 firstEpoch) external {
        new LegacyStaker(firstEpoch);
    }
}