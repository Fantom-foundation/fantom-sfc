const {
    BN,
} = require('openzeppelin-test-helpers');

class TestingGetters {
    constructor(ratioUnitMultiplier, denominator, contractComissionMultiplier, lockPeriodTime, delegationLockPeriodTime, bondedTargetPeriod, unlockPeriod, stakeLockPeriodEpochs, unbondingStartDate, bondedTargetStartRatio, delegationLockPeriodEpochs, maxStakerMetadataSize) {
        this.ratioUnitMultiplier = new BN(ratioUnitMultiplier);
        this.denominator = new BN(denominator);
        this.contractComissionMultiplier = new BN(contractComissionMultiplier);
        this.lockPeriodTime = new BN(lockPeriodTime);
        this.delegationLockPeriodTime = new BN(delegationLockPeriodTime);
        this.bondedTargetPeriod = new BN(bondedTargetPeriod);
        this.unlockPeriod = new BN(unlockPeriod);
        this.stakeLockPeriodEpochs = new BN(stakeLockPeriodEpochs);
        this.unbondingStartDate = new BN(unbondingStartDate);
        this.bondedTargetStartRatio = new BN(bondedTargetStartRatio);
        this.delegationLockPeriodEpochs = new BN(delegationLockPeriodEpochs);
        this.maxStakerMetadataSize= new BN(maxStakerMetadataSize);
    }

    expectedMaxDelegationRatio(RatioUnit) {
        if (!RatioUnit instanceof BN)
            throw("incorrect input parameter");
        return RatioUnit.mul(this.ratioUnitMultiplier);
    }

    expectedValidatorComission(RatioUnit) {
        if (!RatioUnit instanceof BN)
            throw("incorrect input parameter");
        return RatioUnit.mul(this.ratioUnitMultiplier).div(this.denominator);
    }

    expectedContractComission(RatioUnit) {
        if (!RatioUnit instanceof BN)
            throw("incorrect input parameter")
        return this.contractComissionMultiplier.mul(RatioUnit).div(this.denominator);
    }

    expectedbondedTargetStartRatio(RatioUnit) {
        if (!RatioUnit instanceof BN)
            throw("incorrect input parameter")
        return this.bondedTargetStartRatio.mul(RatioUnit).div(this.denominator);
    }
}
module.exports.TestingGetters = TestingGetters;