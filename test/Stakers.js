const {
    BN,
    ether,
    expectRevert,
    time,
    balance,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const TestStakers = artifacts.require('TestStakers');

contract('Staker test', async ([firstStaker, secondStaker, thirdStaker, firstDepositor, secondDepositor]) => {
    beforeEach(async () => {
        this.firstEpoch = 0;
        this.stakers = await TestStakers.new(this.firstEpoch);
    });

    it('checking Staker parameters', async () => {
        expect(await this.stakers.minValidationStake.call()).to.be.bignumber.equal(ether('1.0'));
        expect(await this.stakers.minDelegation.call()).to.be.bignumber.equal(ether('1.0'));
        expect(await this.stakers.percentUnit.call()).to.be.bignumber.equal(new BN('1000000'));
        expect(await this.stakers.maxDelegatedMeRatio.call()).to.be.bignumber.equal(new BN('15000000'));
        expect(await this.stakers.validatorCommission.call()).to.be.bignumber.equal(new BN('150000'));
        expect(await this.stakers.vStakeLockPeriodTime.call()).to.be.bignumber.equal(new BN('86400').mul(new BN('7')));
        expect(await this.stakers.vStakeLockPeriodEpochs.call()).to.be.bignumber.equal(new BN('3'));
        expect(await this.stakers.deleagtionLockPeriodTime.call()).to.be.bignumber.equal(new BN('86400').mul(new BN('7')));
        expect(await this.stakers.deleagtionLockPeriodEpochs.call()).to.be.bignumber.equal(new BN('3'));
    });

    it('checking createVStake function', async () => {
        expect(await this.stakers.vStakersNum.call()).to.be.bignumber.equal(new BN('0'));
        await this.stakers._createVStake({from: firstStaker, value: ether('2.0')});
        await this.stakers._createVStake({from: secondStaker, value: ether('1.01')});
        await expectRevert(this.stakers._createVStake({from: thirdStaker, value: ether('0.99') }), 'insufficient amount for staking');
        await expectRevert(this.stakers._createVStake({from: firstStaker}), 'staker doesn\'t exist yet');

        expect(await this.stakers.vStakersNum.call()).to.be.bignumber.equal(new BN('2'));
        expect(await this.stakers.vStakeTotalAmount.call()).to.be.bignumber.equal(ether('3.01'));
        expect(await this.stakers.vStakersLastIdx.call()).to.be.bignumber.equal(new BN('2'));

        expect((await this.stakers.vStakers.call(firstStaker)).stakeAmount).to.be.bignumber.equal(ether('2.0'));
        expect((await this.stakers.vStakers.call(firstStaker)).createdEpoch).to.be.bignumber.equal(new BN('0'));
        expect((await this.stakers.vStakers.call(firstStaker)).stakerIdx).to.be.bignumber.equal(new BN('1'));

        expect((await this.stakers.vStakers.call(secondStaker)).stakeAmount).to.be.bignumber.equal(ether('1.01'));
        expect((await this.stakers.vStakers.call(secondStaker)).createdEpoch).to.be.bignumber.equal(new BN('0'));
        expect((await this.stakers.vStakers.call(secondStaker)).stakerIdx).to.be.bignumber.equal(new BN('2'));
    });

    it('checking increaseVStake function', async () => {
        await this.stakers._createVStake({from: firstStaker, value: ether('2.0')});
        await this.stakers.increaseVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.increaseVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.increaseVStake({from: firstStaker, value: ether('1.0')});
        await expectRevert(this.stakers.increaseVStake({from: secondStaker, value: ether('1.0') }), 'staker doesn\'t created');

        expect(await this.stakers.vStakeTotalAmount.call()).to.be.bignumber.equal(ether('5.0'));
        expect((await this.stakers.vStakers.call(firstStaker)).stakeAmount).to.be.bignumber.equal(ether('5.0'));
    });

    it('checking createDelegation function', async () => {
        const getDeposition = async (depositor) => this.stakers.delegations.call(depositor);
        const getStaker = async (staker) => this.stakers.vStakers.call(staker);

        await this.stakers._createVStake({from: firstStaker, value: ether('2.0')});

        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('1.0')});
        await expectRevert(this.stakers.createDelegation(secondStaker, {from: secondDepositor, value: ether('1.0')}), 'staker doesn\'t created');
        await expectRevert(this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('0.99')}), 'insufficient amount for delegation');
        await expectRevert(this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('29.01')}), 'delegated limit is exceeded');
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('29.0')});

        const now = await time.latest();

        const firstDepositionEntity = await getDeposition(firstDepositor);
        const firstStakerEntity = await getStaker(firstStaker);
        expect(firstDepositionEntity.amount).to.be.bignumber.equal(ether('1'));
        expect(firstDepositionEntity.createdEpoch).to.be.bignumber.equal(new BN('0'));
        expect(now.sub(firstDepositionEntity.createdTime)).to.be.bignumber.lessThan(new BN('2'));
        expect(firstDepositionEntity.toStakerAddress).to.equal(firstStaker);
        expect(firstDepositionEntity.toStakerIdx).to.be.bignumber.equal(firstStakerEntity.stakerIdx);

        const secondDepositionEntity = await getDeposition(secondDepositor);
        expect(secondDepositionEntity.amount).to.be.bignumber.equal(ether('29'));
        expect(secondDepositionEntity.createdEpoch).to.be.bignumber.equal(new BN('0'));
        expect(now.sub(secondDepositionEntity.createdTime)).to.be.bignumber.lessThan(new BN('2'));
        expect(secondDepositionEntity.toStakerAddress).to.equal(firstStaker);
        expect(secondDepositionEntity.toStakerIdx).to.be.bignumber.equal(firstStakerEntity.stakerIdx);

        expect(firstStakerEntity.delegatedMe).to.be.bignumber.equal(ether('30.0'));
        expect(await this.stakers.delegationsTotalAmount.call()).to.be.bignumber.equal(ether('30.0'));
        expect(await this.stakers.delegationsNum.call()).to.be.bignumber.equal(new BN('2'));
    });

    it('checking calcTotalReward function', async () => {
        await expectRevert(this.stakers._calcTotalReward(firstStaker, new BN('0')), 'total validating power can\'t be null');
        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});

        await this.stakers._createVStake({from: secondStaker, value: ether('1.0')});
        await this.stakers._makeEpochSnapshots(10000);

        expect(await this.stakers._calcTotalReward(firstStaker, new BN('0'))).to.be.bignumber.equal(ether('0.5000000000000025'));
        expect(await this.stakers._calcTotalReward(secondStaker, new BN('0'))).to.be.bignumber.equal(ether('1.5000000000000075'));
    });

    it('checking calcValidatorReward function', async () => {
        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});

        await this.stakers._createVStake({from: secondStaker, value: ether('1.0')});
        await this.stakers._makeEpochSnapshots(10000);

        expect(await this.stakers._calcValidatorReward(firstStaker, new BN('0'))).to.be.bignumber.equal(ether('0.101562500000000507'));
        expect(await this.stakers._calcValidatorReward(secondStaker, new BN('0'))).to.be.bignumber.equal(ether('1.5000000000000075'));

    });

    it('checking calcDelegatorReward function', async () => {
        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});

        await this.stakers._createVStake({from: secondStaker, value: ether('1.0')});
        await this.stakers._makeEpochSnapshots(10000);

        expect(await this.stakers._calcDelegatorReward(firstStaker, new BN('0'), ether('15.0'))).to.be.bignumber.equal(ether('0.398437500000001992'));
    });

    it('checking claimDelegationReward function', async () => {
        await expectRevert(this.stakers.claimDelegationReward(new BN('0'), new BN('1'), {from: firstDepositor}), 'delegation doesn\'t exists');

        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});

        await this.stakers._makeEpochSnapshots(10000);
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});
        await this.stakers._makeEpochSnapshots(10000);

        await expectRevert(this.stakers.claimDelegationReward(new BN('3'), new BN('1'), {from: firstDepositor}), 'invalid fromEpoch');
        await expectRevert(this.stakers.claimDelegationReward(new BN('0'), new BN('3'), {from: firstDepositor}), 'invalid untilEpoch');

        expect(await balance.current(this.stakers.address)).to.be.bignumber.equal(ether('16.0'));
        const balanceBefore = await balance.current(firstDepositor);

        await this.stakers.claimDelegationReward(new BN('0'), new BN('0'), {from: firstDepositor});
        expect(await balance.current(this.stakers.address)).to.be.bignumber.equal(ether('15.468749999999997344')); // 16 - 0.531250000000002656
        await expectRevert(this.stakers.claimDelegationReward(new BN('0'), new BN('0'), {from: firstDepositor}), 'invalid fromEpoch');
        const balanceAfter = await balance.current(firstDepositor);
        expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.equal(ether('0.529540900000002656')); // 0.531250000000002656 - tx fee
    });

    it('checking claimValidatorReward function', async () => {
        await expectRevert(this.stakers.claimValidatorReward(new BN('0'), new BN('1'), {from: firstStaker}), 'staker doesn\'t exists');

        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});

        await this.stakers._makeEpochSnapshots(10000);
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});
        await this.stakers._makeEpochSnapshots(10000);

        await expectRevert(this.stakers.claimValidatorReward(new BN('3'), new BN('1'), {from: firstStaker}), 'invalid fromEpoch');
        await expectRevert(this.stakers.claimValidatorReward(new BN('0'), new BN('3'), {from: firstStaker}), 'invalid untilEpoch');

        expect(await balance.current(this.stakers.address)).to.be.bignumber.equal(ether('16.0'));
        const balanceBefore = await balance.current(firstStaker);

        await this.stakers.claimValidatorReward(new BN('0'), new BN('0'), {from: firstStaker});
        expect(await balance.current(this.stakers.address)).to.be.bignumber.equal(ether('15.593749999999997969')); // 16 - 0.406250000000002031
        await expectRevert(this.stakers.claimValidatorReward(new BN('0'), new BN('0'), {from: firstStaker}), 'invalid fromEpoch');
        const balanceAfter = await balance.current(firstStaker);
        expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.equal(ether('0.404607680000002031')); // 0.406250000000002031 - tx fee
    });

    it('checking prepareToWithdrawVStake function', async () => {
        const getStaker = async (staker) => this.stakers.vStakers.call(staker);

        await expectRevert(this.stakers.prepareToWithdrawVStake({from: firstStaker}), 'staker doesn\'t exists');
        const firstStakerEntityBefore = await getStaker(firstStaker);
        expect(firstStakerEntityBefore.deactivatedEpoch).to.be.bignumber.equal(new BN('0'));
        expect(firstStakerEntityBefore.deactivatedTime).to.be.bignumber.equal(new BN('0'));

        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});

        const now = await time.latest();
        await this.stakers.prepareToWithdrawVStake({from: firstStaker});

        const firstStakerEntityAfter = await getStaker(firstStaker);
        expect(firstStakerEntityAfter.deactivatedEpoch).to.be.bignumber.equal(new BN('0'));
        expect(now.sub(firstStakerEntityAfter.deactivatedTime)).to.be.bignumber.lessThan(new BN('2'));
        await expectRevert(this.stakers.prepareToWithdrawVStake({from: firstStaker}), 'staker can\'t be deactivated yet');
    });

    it('checking prepareToWithdrawDelegation function', async () => {
        const getDeposition = async (depositor) => this.stakers.delegations.call(depositor);

        await expectRevert(this.stakers.prepareToWithdrawDelegation({from: firstDepositor}), 'delegation doesn\'t exists');
        const firstDepositorEntityBefore = await getDeposition(firstDepositor);
        expect(firstDepositorEntityBefore.deactivatedEpoch).to.be.bignumber.equal(new BN('0'));
        expect(firstDepositorEntityBefore.deactivatedTime).to.be.bignumber.equal(new BN('0'));

        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});

        const now = await time.latest();
        await this.stakers.prepareToWithdrawDelegation({from: firstDepositor});

        const firstDepositorEntityAfter = await getDeposition(firstDepositor);
        expect(firstDepositorEntityAfter.deactivatedEpoch).to.be.bignumber.equal(new BN('0'));
        expect(now.sub(firstDepositorEntityAfter.deactivatedTime)).to.be.bignumber.lessThan(new BN('2'));
        await expectRevert(this.stakers.prepareToWithdrawDelegation({from: firstDepositor}), 'delegation can\'t be deactivated yet');
    });
});
