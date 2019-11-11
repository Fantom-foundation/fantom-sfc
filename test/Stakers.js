const {
    BN,
    ether,
    expectRevert,
    time,
    balance,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const TestStakers = artifacts.require('TestStakers');

contract('Staker test', async ([firstStaker, secondStaker, thirdStaker, firstDepositor, secondDepositor, thirdDepositor]) => {
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
        const getDeposition = async (depositor, number) => this.stakers.delegations.call(depositor, number);
        const getStaker = async (staker) => this.stakers.vStakers.call(staker);

        await this.stakers._createVStake({from: firstStaker, value: ether('2.0')});

        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('1.0')});
        await expectRevert(this.stakers.createDelegation(secondStaker, {from: secondDepositor, value: ether('1.0')}), 'staker doesn\'t created');
        await expectRevert(this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('0.99')}), 'insufficient amount for delegation');
        await expectRevert(this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('29.01')}), 'delegated limit is exceeded');
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('29.0')});

        const now = await time.latest();

        const firstDepositionEntity = await getDeposition(firstDepositor, new BN('0'));
        const firstStakerEntity = await getStaker(firstStaker);
        expect(firstDepositionEntity.amount).to.be.bignumber.equal(ether('1'));
        expect(firstDepositionEntity.createdEpoch).to.be.bignumber.equal(new BN('0'));
        expect(now.sub(firstDepositionEntity.createdTime)).to.be.bignumber.lessThan(new BN('2'));
        expect(firstDepositionEntity.toStakerAddress).to.equal(firstStaker);
        expect(firstDepositionEntity.toStakerIdx).to.be.bignumber.equal(firstStakerEntity.stakerIdx);

        const secondDepositionEntity = await getDeposition(secondDepositor, new BN('0'));
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
        await expectRevert(this.stakers._calcTotalReward(firstStaker, new BN('0')), 'total validating power can\'t be null');
        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});

        await this.stakers._createVStake({from: secondStaker, value: ether('1.0')});
        await this.stakers._makeEpochSnapshots(10000);

        expect(await this.stakers._calcValidatorReward(firstStaker, new BN('0'))).to.be.bignumber.equal(ether('0.101562500000000507'));
        expect(await this.stakers._calcValidatorReward(secondStaker, new BN('0'))).to.be.bignumber.equal(ether('1.5000000000000075'));

    });

    it('checking calcDelegatorReward function', async () => {
        await expectRevert(this.stakers._calcTotalReward(firstStaker, new BN('0')), 'total validating power can\'t be null');
        await this.stakers._createVStake({from: firstStaker, value: ether('1.0')});
        await this.stakers.createDelegation(firstStaker, {from: firstDepositor, value: ether('5.0')});
        await this.stakers.createDelegation(firstStaker, {from: secondDepositor, value: ether('10.0')});

        await this.stakers._createVStake({from: secondStaker, value: ether('1.0')});
        await this.stakers._makeEpochSnapshots(10000);

        expect(await this.stakers._calcDelegatorReward(firstStaker, new BN('0'), ether('15.0'))).to.be.bignumber.equal(ether('0.398437500000001992'));
    });
});
