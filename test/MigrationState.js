const {
  BN,
  ether,
  expectRevert,
  time,
  balance,
  constants,
} = require('openzeppelin-test-helpers');
const {expect} = require('chai');

const { ZERO_ADDRESS } = constants;

const assertEqual = (a, b) => assert.isTrue(Object.is(a, b), `Expected ${a.toString()} to equal ${b.toString()}`);

const LegacyStaker = artifacts.require('LegacyStaker');
const Factory = artifacts.require('Factory');

const getLegacyDeposition = async (depositor) => this.stakers.delegations.call(depositor);
const getDeposition = async (depositor, to) => this.stakers.delegations_v2.call(depositor, to);
const getStaker = async (stakerID) => this.stakers.stakers.call(stakerID);
const createLegacyDelegation = async(depositor, stakerID, amount, epoch) => {
  await this.stakers.createLegacyDelegation(stakerID, { from: depositor, value: amount});
  const now = await time.latest();
  const deposition = await getLegacyDeposition(depositor);

  expect(deposition.amount).to.be.bignumber.equal(amount);
  expect(deposition.createdEpoch).to.be.bignumber.equal(epoch);
  expect(now.sub(deposition.createdTime)).to.be.bignumber.lt(new BN('3'));
  expect(deposition.toStakerID).to.be.bignumber.equal(stakerID);
}

contract('Migration tests', async ([firstStaker, secondStaker, firstDepositor, secondDepositor, thirdDepositor, fourthDepositor, fifthDepositor]) => {
  describe ('migration delegate tests', async () => {
    before(async () => {
       const factory = await Factory.new();
       const response = await factory.createLegacyStaker(0);
       console.log('\tdeploying gas used:', response.receipt.gasUsed.toString(10));
    });

    beforeEach(async () => {
      this.firstEpoch = 0;
      this.stakers = await LegacyStaker.new(this.firstEpoch);
      this.validatorComission = new BN('150000'); // 0.15
    });

    it('auto migrate legacy deposition to new model', async () => {
      // create 5 legacy delegation
      await this.stakers._createStake({ from: firstStaker, value: ether('2.0')});
      const firstStakerID = await this.stakers.getStakerID(firstStaker);
      const currentEpoch = (await this.stakers.currentSealedEpoch()).add(new BN ('1'));
      const delegationAmount = ether('2.0');
      await createLegacyDelegation(firstDepositor, firstStakerID, delegationAmount, currentEpoch);
      await createLegacyDelegation(secondDepositor, firstStakerID, delegationAmount, currentEpoch);
      await createLegacyDelegation(thirdDepositor, firstStakerID, delegationAmount, currentEpoch);
      await createLegacyDelegation(fourthDepositor, firstStakerID, delegationAmount, currentEpoch);
      await createLegacyDelegation(fifthDepositor, firstStakerID, delegationAmount, currentEpoch);
      // check stake with legacy delegations
      const firstStakerEntity = await getStaker(firstStakerID);
      expect(firstStakerEntity.delegatedMe).to.be.bignumber.equal(delegationAmount.mul(new BN('5')));
      expect(await this.stakers.delegationsTotalAmount.call()).to.be.bignumber.equal(delegationAmount.mul(new BN('5')));
      expect(await this.stakers.delegationsNum.call()).to.be.bignumber.equal(new BN('5'));
      // check legacy delegations
      expect((await getLegacyDeposition(firstDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      expect((await getLegacyDeposition(secondDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      expect((await getLegacyDeposition(thirdDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      expect((await getLegacyDeposition(fourthDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      expect((await getLegacyDeposition(fifthDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      //  migrate first delegation (increaseDelegation)
      await this.stakers.increaseDelegation(firstStakerID, { from: firstDepositor, value: delegationAmount});
      // migrate second delegation (claimDelegationRewards)
      await this.stakers._makeEpochSnapshots(5);
      await this.stakers.claimDelegationRewards(currentEpoch, firstStakerID, { from: secondDepositor });
      // migrate third delegation (prepareToWithdrawDelegation)
      await this.stakers.discardDelegationRewards(firstStakerID, { from: thirdDepositor });
      await this.stakers.prepareToWithdrawDelegation(firstStakerID, { from: thirdDepositor });
      // migrate fourth delegation (prepareToWithdrawDelegationPartial)
      const wrID = new BN('0');
      await this.stakers.discardDelegationRewards(firstStakerID, { from: fourthDepositor });
      await this.stakers.prepareToWithdrawDelegationPartial(wrID, firstStakerID, delegationAmount.div(new BN('2')), { from: fourthDepositor });
      // migrate fifth delegation (withdrawDelegation)
      await this.stakers.discardDelegationRewards(firstStakerID, { from: fifthDepositor });
      await this.stakers.prepareToWithdrawLegacyDelegation({ from: fifthDepositor });
      time.increase(86400 * 7);
      await this.stakers._makeEpochSnapshots(5);
      await this.stakers._makeEpochSnapshots(5);
      await this.stakers._makeEpochSnapshots(5);
      await this.stakers.withdrawDelegation(firstStakerID, { from: fifthDepositor });
      // check removed legacy delegations
      expect((await getLegacyDeposition(firstDepositor)).amount).to.be.bignumber.equal(new BN('0'));
      expect((await getLegacyDeposition(secondDepositor)).amount).to.be.bignumber.equal(new BN('0'));
      expect((await getLegacyDeposition(thirdDepositor)).amount).to.be.bignumber.equal(new BN('0'));
      expect((await getLegacyDeposition(fourthDepositor)).amount).to.be.bignumber.equal(new BN('0'));
      expect((await getLegacyDeposition(fifthDepositor)).amount).to.be.bignumber.equal(new BN('0'));
      // check delegation in new model
      expect((await getDeposition(firstDepositor, firstStakerID)).toStakerID).to.be.bignumber.equal(firstStakerID);
      expect((await getDeposition(secondDepositor, firstStakerID)).toStakerID).to.be.bignumber.equal(firstStakerID);
      expect((await getDeposition(thirdDepositor, firstStakerID)).toStakerID).to.be.bignumber.equal(firstStakerID);
      expect((await getDeposition(fourthDepositor, firstStakerID)).toStakerID).to.be.bignumber.equal(firstStakerID);
      // expect((await getDeposition(fifthDepositor, firstStakerID)).toStakerID).to.be.bignumber.equal(firstStakerID); // can't check because withdrawDelegation removes delegation entity
    });

    it('manually migrate legacy deposition to new model', async () => {
      // create legacy delegation
      await this.stakers._createStake({ from: firstStaker, value: ether('2.0')});
      const firstStakerID = await this.stakers.getStakerID(firstStaker);
      const currentEpoch = (await this.stakers.currentSealedEpoch()).add(new BN ('1'));
      const delegationAmount = ether('2.0');
      await createLegacyDelegation(firstDepositor, firstStakerID, delegationAmount, currentEpoch);
      // check legacy delegations
      expect((await getLegacyDeposition(firstDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      // migrate delegation (_syncDelegator)
      await this.stakers._syncDelegator(firstDepositor, firstStakerID);
      // check removed legacy delegations
      expect((await getLegacyDeposition(firstDepositor)).amount).to.be.bignumber.equal(new BN('0'));
      // check delegation in new model
      expect((await getDeposition(firstDepositor, firstStakerID)).toStakerID).to.be.bignumber.equal(firstStakerID);
    });

    it('can\'t call calcDelegationRewards while delegation is in the legacy model', async () => {
      // create legacy delegation
      await this.stakers._createStake({ from: firstStaker, value: ether('2.0')});
      const firstStakerID = await this.stakers.getStakerID(firstStaker);
      const currentEpoch = (await this.stakers.currentSealedEpoch()).add(new BN ('1'));
      const delegationAmount = ether('2.0');
      await createLegacyDelegation(firstDepositor, firstStakerID, delegationAmount, currentEpoch);
      // check legacy delegations
      expect((await getLegacyDeposition(firstDepositor)).amount).to.be.bignumber.equal(delegationAmount);
      // can't call calcDelegationRewards while delegation is in the legacy model
      await this.stakers._makeEpochSnapshots(5);
      await this.stakers._makeEpochSnapshots(5);
      await expectRevert(this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, new BN('0'), currentEpoch), "old version delegation, please update");
      // migrate delegation (_syncDelegator)
      await this.stakers._syncDelegator(firstDepositor, firstStakerID);
      // call calcDelegationRewards
      const rewards = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, new BN('0'), currentEpoch);
      expect(rewards[0]).to.be.bignumber.equal(new BN('595000000212500000'));
      expect(rewards[1]).to.be.bignumber.equal(new BN('1'));
      expect(rewards[2]).to.be.bignumber.equal(new BN('1'));
  })
  });
});