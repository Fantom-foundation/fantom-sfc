pragma solidity ^0.5.0;

import "./SafeMath.sol";

contract StakersConstants {
    using SafeMath for uint256;

    uint256 internal constant OK_STATUS = 0;
    uint256 internal constant FORK_BIT = 1;
    uint256 internal constant OFFLINE_BIT = 1 << 8;
    uint256 internal constant CHEATER_MASK = FORK_BIT;
    uint256 internal constant RATIO_UNIT = 1e6;

    /**
     * @dev Minimum amount of stake for a validator, i.e., 3175000 FTM
     */
    function minStake() public pure returns (uint256) {
        // 3175000 FTM
        return 3175000 * 1e18;
    }

    /**
     * @dev Minimum amount of stake for an increase, i.e., 1 FTM
     */
    function minStakeIncrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    /**
     * @dev Minimum amount of stake for a decrease, i.e., 1 FTM
     */
    function minStakeDecrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    /**
     * @dev Minimum amount for a delegation, i.e., 1 FTM
     */
    function minDelegation() public pure returns (uint256) {
        return 1 * 1e18;
    }

    /**
     * @dev Minimum amount to increase a delegation, i.e., 1 FTM
     */
    function minDelegationIncrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    /**
     * @dev Minimum amount to decrease a delegation, i.e., 1 FTM
     */
    function minDelegationDecrease() public pure returns (uint256) {
        return 1 * 1e18;
    }

    /**
     * @dev Maximum ratio of delegations a validator can have, say, 15 times of self-stake
     */
    function maxDelegatedRatio() public pure returns (uint256) {
        // 1500%
        return 15 * RATIO_UNIT;
    }

    /**
     * @dev The commission fee in percentage a validator will get from a delegation, e.g., 15%
     */
    function validatorCommission() public pure returns (uint256) {
        // 15%
        return (15 * RATIO_UNIT) / 100;
    }

    /**
     * @dev The commission fee in percentage a validator will get from a contract, e.g., 30%
     */
    function contractCommission() public pure returns (uint256) {
        // 30%
        return (30 * RATIO_UNIT) / 100;
    }

    /**
     * @dev The ratio of the reward rate at base rate (no lock), e.g., 30%
     */
    function unlockedRewardRatio() public pure returns (uint256) {
        // 30%
        return (30 * RATIO_UNIT) / 100;
    }

    /**
     * @dev The minimum duration of a stake/delegation lockup, e.g. 2 weeks
     */
    function minLockupDuration() public pure returns (uint256) {
        return 86400 * 14;
    }

    /**
     * @dev The maximum duration of a stake/delegation lockup, e.g. 1 year
     */
    function maxLockupDuration() public pure returns (uint256) {
        return 86400 * 365;
    }

    /**
     * @dev the period of time that stake is locked
     */
    function stakeLockPeriodTime() public pure returns (uint256) {
        // 7 days
        return 60 * 60 * 24 * 7;
    }

    /**
     * @dev the number of epochs that stake is locked
     */
    function stakeLockPeriodEpochs() public pure returns (uint256) {
        return 3;
    }

    function delegationLockPeriodTime() public pure returns (uint256) {
        // 7 days
        return 60 * 60 * 24 * 7;
    }

    /**
     * @dev number of epochs to lock a delegation
     */
    function delegationLockPeriodEpochs() public pure returns (uint256) {
        return 3;
    }

    /**
     * @dev maximum size of metadata for staker
     */
    function maxStakerMetadataSize() public pure returns (uint256) {
        return 256;
    }

    event UpdatedBaseRewardPerSec(uint256 value);
    event UpdatedGasPowerAllocationRate(uint256 short, uint256 long);
    event UpdatedOfflinePenaltyThreshold(uint256 blocksNum, uint256 period);
}
