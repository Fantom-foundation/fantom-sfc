const {
  BN,
  ether,
  expectRevert,
  time,
  balance,
} = require('openzeppelin-test-helpers');
const {expect} = require('chai');

const UnitTestStakers = artifacts.require('UnitTestStakers');
const getDeposition = async (depositor, to) => this.stakers.delegations.call(depositor, to);
const getStaker = async (stakerID) => this.stakers.stakers.call(stakerID);

contract('SFC', async ([firstStaker, secondStaker, thirdStaker, firstDepositor, secondDepositor, thirdDepositor]) => {
  beforeEach(async () => {
    this.firstEpoch = 0;
    this.stakers = await UnitTestStakers.new(this.firstEpoch);
    this.validatorComission = new BN('150000'); // 0.15
  });

  describe ('Locking stake tests', async () => {
    it('should start \"locked stake\" feature', async () => {
      await this.stakers.makeEpochSnapshots(5, true);
      await this.stakers.makeEpochSnapshots(5, true);
      const sfc_owner = firstStaker; // first address from contract parameters
      const other_address = secondStaker;
      const currentEpoch = await this.stakers.currentEpoch.call();
      await expectRevert(this.stakers.startLockedUp(currentEpoch, { from: other_address }), "Ownable: caller is not the owner");
      await this.stakers.startLockedUp(currentEpoch.add(new BN('5')), { from: sfc_owner });
      expect(await this.stakers.firstLockedUpEpoch.call()).to.be.bignumber.equal(currentEpoch.add(new BN('5')));
      await expectRevert(this.stakers.startLockedUp(currentEpoch.sub((new BN('1'))), { from: sfc_owner }), "can't start in the past");
      await this.stakers.startLockedUp(currentEpoch, { from: sfc_owner });
      expect(await this.stakers.firstLockedUpEpoch.call()).to.be.bignumber.equal(currentEpoch);
      await this.stakers.makeEpochSnapshots(5, true);
      await this.stakers.makeEpochSnapshots(5, true);
      const newEpoch = await this.stakers.currentEpoch.call();
      await expectRevert(this.stakers.startLockedUp(newEpoch, { from: sfc_owner }), "feature was started");
    });

    it('should calc ValidatorEpochReward correctly after locked up started', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('5.0')});
      await this.stakers.createDelegation(firstStakerID, {from: secondDepositor, value: ether('10.0')});

      await this.stakers._createStake({from: secondStaker, value: ether('1.0')});
      let secondStakerID = await this.stakers.getStakerID(secondStaker);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      await this.stakers._createStake({from: thirdStaker, value: ether('2.0')});
      let thirdStakerID = await this.stakers.getStakerID(thirdStaker);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      let epoch = new BN('1');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000191176470588'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000058823529411'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0'));

      epoch = new BN('2');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      epoch = new BN('3');
      // last epoch without LockedUp
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const currentEpoch = await this.stakers.currentEpoch.call();
      expect(currentEpoch).to.be.bignumber.equal(new BN("4"));
      await this.stakers.startLockedUp(currentEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #4
      epoch = new BN('4');
      // reduce unlock stake by 70%
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #5
      epoch = new BN('5');
      // reduce unlock stake by 70%
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
    });

    it('should lock stake', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('5.0')});
      await this.stakers.createDelegation(firstStakerID, {from: thirdDepositor, value: ether('10.0')});

      await this.stakers._createStake({from: secondStaker, value: ether('1.0')});
      let secondStakerID = await this.stakers.getStakerID(secondStaker);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      await this.stakers._createStake({from: thirdStaker, value: ether('2.0')});
      let thirdStakerID = await this.stakers.getStakerID(thirdStaker);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      let epoch = new BN('1');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000191176470588'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000058823529411'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0'));

      epoch = new BN('2');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      epoch = new BN('3');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));

      const duration = (new BN('86400')).mul(new BN('365'));
      await expectRevert(this.stakers.lockUpStake(duration, { from: firstStaker }), "feature was not activated");
      // start LockedUp
      const sfc_owner = firstStaker;
      const currentEpoch = await this.stakers.currentEpoch.call();
      expect(currentEpoch).to.be.bignumber.equal(new BN("4"));
      const startLockedUpEpoch = new BN("5");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await expectRevert(this.stakers.lockUpStake(duration, { from: firstStaker }), "feature was not activated");

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #4
      epoch = new BN('4');
      // last epoch without LockedUp
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000223684210526'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000447368421052'));

      await this.stakers.lockUpStake(duration, { from: firstStaker });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #5
      epoch = new BN('5');

      // locked up staker receives 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631577'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));

      time.increase(10000);
      await this.stakers.lockUpStake(duration, { from: secondStaker });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #6
      epoch = new BN('6');
      // locked up stakers receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631577'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578946'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));

      // first locking has ended
      time.increase(duration.sub(new BN("9999")));
      await this.stakers.makeEpochSnapshots(0, true); // epoch #7
      epoch = new BN('8');
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #8
      // locked up stakers receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578946'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));

      // second locking has ended
      epoch = new BN('9');
      time.increase(10002);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #9
      // locked up stakers receive 100% reward
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));
    });

    it('should lock stake with right duration', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      await this.stakers._createStake({from: secondStaker, value: ether('1.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const minDuration = (new BN('86400')).mul(new BN('14'));
      const maxDuration = (new BN('86400')).mul(new BN('365'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await expectRevert(this.stakers.lockUpStake(minDuration.sub(new BN("1")), { from: firstStaker }), "incorrect duration");
      await this.stakers.lockUpStake(minDuration, { from: firstStaker });
      await expectRevert(this.stakers.lockUpStake(maxDuration.add(new BN("1")), { from: secondStaker }), "incorrect duration");
      await this.stakers.lockUpStake(maxDuration, { from: secondStaker });
      await expectRevert(this.stakers.lockUpStake(minDuration, { from: secondStaker }), "already locked up");
      await expectRevert(this.stakers.lockUpStake(maxDuration, { from: firstStaker }), "already locked up");
      time.increase(maxDuration.add(new BN("3")));
      await expectRevert(this.stakers.lockUpStake(maxDuration, { from: firstStaker }), "not all lockup rewards claimed");
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      await expectRevert(this.stakers.lockUpStake(maxDuration, { from: firstStaker }), "not all lockup rewards claimed");
      await this.stakers.discardValidatorRewards({ from: firstStaker });
      await this.stakers.lockUpStake(maxDuration, { from: firstStaker });
      await this.stakers.discardValidatorRewards({ from: secondStaker });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #4
      await this.stakers.lockUpStake(maxDuration, { from: secondStaker });
    });

    it('should not call prepareToWithdrawStake, until locked time is passed', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('14'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration, { from: firstStaker });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      await this.stakers.discardValidatorRewards({from: firstStaker});
      await expectRevert(this.stakers.prepareToWithdrawStake({ from: firstStaker }), "stake is locked");
      time.increase(86400 * 14 - 2);
      await expectRevert(this.stakers.prepareToWithdrawStake({ from: firstStaker }), "stake is locked");
      time.increase(3);
      await this.stakers.prepareToWithdrawStake({ from: firstStaker });
    });

    it('should not call prepareToWithdrawStakePartial, until locked time is passed', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('2.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('14'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration, { from: firstStaker });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      await this.stakers.discardValidatorRewards({from: firstStaker});
      const wrID = new BN('1');
      await expectRevert(this.stakers.prepareToWithdrawStakePartial(wrID, ether('1.0'), { from: firstStaker }), "stake is locked");
      time.increase(86400 * 14 - 2);
      await expectRevert(this.stakers.prepareToWithdrawStakePartial(wrID, ether('1.0'), { from: firstStaker }), "stake is locked");
      time.increase(3);
      await this.stakers.prepareToWithdrawStakePartial(wrID, ether('1.0'), { from: firstStaker });
    });

    it('should lock delegation', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('5.0')});
      await this.stakers.createDelegation(firstStakerID, {from: thirdDepositor, value: ether('10.0')});

      await this.stakers._createStake({from: secondStaker, value: ether('1.0')});
      let secondStakerID = await this.stakers.getStakerID(secondStaker);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      await this.stakers._createStake({from: thirdStaker, value: ether('2.0')});
      let thirdStakerID = await this.stakers.getStakerID(thirdStaker);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      let epoch = new BN('1');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000191176470588'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000058823529411'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000249999999999'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000499999999999'));

      epoch = new BN('2');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      epoch = new BN('3');
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));

      const duration = (new BN('86400')).mul(new BN('14'));
      await expectRevert(this.stakers.lockUpStake(duration, { from: firstStaker }), "feature was not activated");
      // start LockedUp
      const sfc_owner = firstStaker;
      const currentEpoch = await this.stakers.currentEpoch.call();
      expect(currentEpoch).to.be.bignumber.equal(new BN("4"));
      const startLockedUpEpoch = new BN("5");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await expectRevert(this.stakers.lockUpStake(duration, { from: firstStaker }), "feature was not activated");

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #4
      epoch = new BN('4');
      // last epoch without LockedUp
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000105263157894'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000223684210526'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000447368421052'));

      await this.stakers.lockUpStake(duration.add(new BN("10005")), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #5
      epoch = new BN('5');

      // locked up stakers/delegators receive 30% + 70%*14/365 = 32.68% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000055946355262'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000073110960525'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));

      time.increase(10000);
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: thirdDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #6
      epoch = new BN('6');
      // locked up stakers/delegators receive 30% + 70%*14/365 = 32.68% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000055946355262'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000073110960525'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000146221921051'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));

      // first locking has ended
      time.increase(86400 * 14 - 9900);
      await this.stakers.makeEpochSnapshots(0, true); // epoch #7
      epoch = new BN('8');
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #8
      // locked up stakers/delegators receive 30% + 70%*14/365 = 32.68% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000055946355262'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000146221921051'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));

      // second locking has ended
      epoch = new BN('9');
      time.increase(10102);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #9
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));
    });

    it('should lock delegation with right duration', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      await this.stakers._createStake({from: secondStaker, value: ether('1.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      let secondStakerID = await this.stakers.getStakerID(secondStaker);
      await this.stakers.createDelegation(secondStakerID, {from: firstDepositor, value: ether('1.0')});
      await this.stakers.createDelegation(firstStakerID, {from: secondDepositor, value: ether('1.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const minDuration = (new BN('86400')).mul(new BN('14'));
      const maxDuration = (new BN('86400')).mul(new BN('365'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(maxDuration, { from: firstStaker });
      await this.stakers.lockUpStake(minDuration.mul(new BN("3")), { from: secondStaker });

      await expectRevert(this.stakers.lockUpDelegation(minDuration.sub(new BN("1")), secondStakerID, { from: firstDepositor }), "incorrect duration");
      await this.stakers.lockUpDelegation(minDuration, secondStakerID, { from: firstDepositor });
      await expectRevert(this.stakers.lockUpDelegation(maxDuration.add(new BN("1")), firstStakerID, { from: secondDepositor }), "incorrect duration");
      await this.stakers.lockUpDelegation(maxDuration.sub(new BN("1")), firstStakerID, { from: secondDepositor });
      await expectRevert(this.stakers.lockUpDelegation(minDuration, firstStakerID, { from: secondDepositor }), "already locked up");
      await expectRevert(this.stakers.lockUpDelegation(minDuration.mul(new BN("4")), secondStakerID, { from: firstDepositor }), "staker's locking will finish first");
      await expectRevert(this.stakers.lockUpDelegation(minDuration.add(new BN("2")), secondStakerID, { from: firstDepositor }), "already locked up");
      time.increase(minDuration.add(new BN("3")));
      await expectRevert(this.stakers.lockUpDelegation(minDuration.add(new BN("2")), secondStakerID, { from: firstDepositor }), "not all lockup rewards claimed");
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3
      await expectRevert(this.stakers.lockUpDelegation(minDuration.add(new BN("2")), secondStakerID, { from: firstDepositor }), "not all lockup rewards claimed");
      await this.stakers.discardDelegationRewards(secondStakerID, { from: firstDepositor });
      await this.stakers.lockUpDelegation(minDuration.add(new BN("2")), secondStakerID, { from: firstDepositor });
    });

    it('should subtract penalty if prepareToWithdrawDelegation will call earlier than locked time is passed', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('10.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('1.0')});
      await this.stakers.createDelegation(firstStakerID, {from: secondDepositor, value: ether('1.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('73')); // 20% of lockup period
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration.add(new BN('5')), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: secondDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3

      await this.stakers.claimDelegationRewards(2, firstStakerID, {from: firstDepositor});
      const penaltyNonLocked = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penaltyNonLocked).to.be.bignumber.equal(ether('0.0')); // penalty must be zero for non-lockup epochs

      const reward = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, 0, 1);
      expect(reward[0]).to.be.bignumber.equal(ether('0.000000031166666665'));
      await this.stakers.claimDelegationRewards(100, firstStakerID, {from: firstDepositor});
      await this.stakers.claimDelegationRewards(100, firstStakerID, {from: secondDepositor});
      const penalty = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penalty).to.be.bignumber.equal(ether('0.000000020541666665')); // (50% of base reward + 100% of extra reward) * 1.0 FTM / 1.0 FTM

      time.increase(duration.sub(new BN("2"))); // not unlocked yet

      await this.stakers.prepareToWithdrawDelegation(firstStakerID, { from: firstDepositor });
      const firstDeposition = await getDeposition(firstDepositor, firstStakerID);
      expect(firstDeposition.amount).to.be.bignumber.equal(ether('1.0').sub(penalty));

      time.increase(3); // after lockup

      await this.stakers.prepareToWithdrawDelegation(firstStakerID, { from: secondDepositor });
      const secondDeposition = await getDeposition(secondDepositor, firstStakerID);
      expect(secondDeposition.amount).to.be.bignumber.equal(ether('1.0'));

      // check withdrawal amount
      await expectRevert(this.stakers.withdrawDelegation(firstStakerID, { from: firstDepositor }), "not enough time passed");
      time.increase(duration);
      await expectRevert(this.stakers.withdrawDelegation(firstStakerID, { from: firstDepositor }), "not enough epochs passed");
      await this.stakers.makeEpochSnapshots(10000, false);
      await this.stakers.makeEpochSnapshots(10000, false);
      await this.stakers.makeEpochSnapshots(10000, false);

      const balanceStakersBefore = await balance.current(this.stakers.address);
      const balanceDelegatorBefore = await balance.current(firstDepositor);
      await this.stakers.withdrawDelegation(firstStakerID, { from: firstDepositor });
      const balanceStakersAfter = await balance.current(this.stakers.address);
      const balanceDelegatorAfter = await balance.current(firstDepositor);

      expect(balanceStakersAfter).to.be.bignumber.equal(balanceStakersBefore.sub(firstDeposition.amount));
      expect(balanceDelegatorAfter).to.be.bignumber.least(balanceDelegatorBefore.add(firstDeposition.amount).sub(ether('0.005')));
    });

    it('should adjust penalty if penalty is bigger than delegated stake', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('10.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('10.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('350')); // 350/365 days
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration.add(new BN('5')), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.makeEpochSnapshots(86400 * 365 * 10000, false); // epoch #3

      const reward = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, 0, 100);
      expect(reward[0]).to.be.bignumber.equal(ether('13.017228802100000000'));
      await this.stakers.claimDelegationRewards(100, firstStakerID, {from: firstDepositor});
      const penalty = await this.stakers.delegationEarlyWithdrawalPenalty(firstDepositor, firstStakerID);
      expect(penalty).to.be.bignumber.equal(ether('11.006808249600000000')); // biggger than delegator's stake

      time.increase(duration.sub(new BN("2"))); // not unlocked yet

      const wrID1 = new BN('1');
      await this.stakers.prepareToWithdrawDelegationPartial(wrID1, firstStakerID, ether('1.0'), { from: firstDepositor });
      const firstDepositionAfterPartial = await getDeposition(firstDepositor, firstStakerID);
      const firstRequest = await this.stakers.withdrawalRequests(firstDepositor, wrID1);
      expect(firstDepositionAfterPartial.amount).to.be.bignumber.equal(ether('9.0'));
      expect(firstRequest.amount).to.be.bignumber.equal(ether('0.000000000000000001'));
      const penaltyAfterPartial = await this.stakers.delegationEarlyWithdrawalPenalty(firstDepositor, firstStakerID);
      expect(penaltyAfterPartial).to.be.bignumber.equal(ether('10.006808249600000001'));

      await this.stakers.prepareToWithdrawDelegation(firstStakerID, { from: firstDepositor });
      const firstDepositionAfterFull = await getDeposition(firstDepositor, firstStakerID);
      expect(firstDepositionAfterFull.amount).to.be.bignumber.equal(ether('0.000000000000000001'));
      const penaltyAfterFull = await this.stakers.delegationEarlyWithdrawalPenalty(firstDepositor, firstStakerID);
      expect(penaltyAfterFull).to.be.bignumber.equal(ether('1.006808249600000002'));
    });

    it('should subtract penalty if prepareToWithdrawDelegationPartial is called earlier than locked time is passed', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('20.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('2.0')});
      await this.stakers.createDelegation(firstStakerID, {from: secondDepositor, value: ether('2.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('73')); // 20% of lockup period
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration.add(new BN('5')), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: secondDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3

      await this.stakers.claimDelegationRewards(2, firstStakerID, {from: firstDepositor});
      const penaltyNonLocked = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penaltyNonLocked).to.be.bignumber.equal(ether('0.0')); // penalty must be zero for non-lockup epochs

      const reward = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, 0, 1);
      expect(reward[0]).to.be.bignumber.equal(ether('0.000000031166666665'));
      await this.stakers.claimDelegationRewards(100, firstStakerID, {from: firstDepositor});
      await this.stakers.claimDelegationRewards(100, firstStakerID, {from: secondDepositor});
      const penalty = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penalty).to.be.bignumber.equal(ether('0.000000010270833332')); // (50% of base reward + 100% of extra reward) * 1.0 FTM / 2.0 FTM

      time.increase(duration.sub(new BN("2")));// not unlocked yet

      const wrID1 = new BN('1');
      await this.stakers.prepareToWithdrawDelegationPartial(wrID1, firstStakerID, ether('1.0'), { from: firstDepositor });
      const firstDeposition = await getDeposition(firstDepositor, firstStakerID);
      const firstRequest = await this.stakers.withdrawalRequests(firstDepositor, wrID1);
      expect(firstDeposition.amount).to.be.bignumber.equal(ether('1.0'));
      expect(firstRequest.amount).to.be.bignumber.equal(ether('1.0').sub(penalty));

      time.increase(3); // after lockup

      const wrID2 = new BN('2');
      await this.stakers.prepareToWithdrawDelegationPartial(wrID2, firstStakerID, ether('1.0'), { from: secondDepositor });
      const secondDeposition = await getDeposition(secondDepositor, firstStakerID);
      const secondRequest = await this.stakers.withdrawalRequests(secondDepositor, wrID2);
      expect(secondDeposition.amount).to.be.bignumber.equal(ether('1.0'));
      expect(secondRequest.amount).to.be.bignumber.equal(ether('1.0'));

      // check withdrawal amount
      await expectRevert(this.stakers.partialWithdrawByRequest(wrID1, { from: firstDepositor }), "not enough time passed");
      time.increase(duration);
      await expectRevert(this.stakers.partialWithdrawByRequest(wrID1, { from: firstDepositor }), "not enough epochs passed");
      await this.stakers.makeEpochSnapshots(10000, false);
      await this.stakers.makeEpochSnapshots(10000, false);
      await this.stakers.makeEpochSnapshots(10000, false);

      const balanceStakersBefore = await balance.current(this.stakers.address);
      const balanceDelegatorBefore = await balance.current(firstDepositor);
      await this.stakers.partialWithdrawByRequest(wrID1, { from: firstDepositor });
      const balanceStakersAfter = await balance.current(this.stakers.address);
      const balanceDelegatorAfter = await balance.current(firstDepositor);

      expect(balanceStakersAfter).to.be.bignumber.equal(balanceStakersBefore.sub(firstRequest.amount));
      expect(balanceDelegatorAfter).to.be.bignumber.least(balanceDelegatorBefore.add(firstRequest.amount).sub(ether('0.005')));
    });

    const checkClaimReward = async (addr, stakerID, isDelegator, expectation) => {
      // check amounts
      const rewards = isDelegator ? await this.stakers.calcDelegationLockupRewards(addr, stakerID, 0, 1) :
          await this.stakers.calcValidatorLockupRewards(stakerID, 0, 1);
      expect(rewards.unlockedReward).to.be.bignumber.equal(expectation.unlockedReward);
      expect(rewards.lockupBaseReward).to.be.bignumber.equal(expectation.lockupBaseReward);
      expect(rewards.lockupExtraReward).to.be.bignumber.equal(expectation.lockupExtraReward);
      expect(rewards.burntReward).to.be.bignumber.equal(expectation.burntReward);
      expect(rewards.fromEpoch).to.be.bignumber.equal(expectation.epoch);
      expect(rewards.untilEpoch).to.be.bignumber.equal(expectation.epoch);
      // check claiming
      const balanceStakersBefore = await balance.current(this.stakers.address);
      const totalBurntLockupRewardsBefore = await this.stakers.totalBurntLockupRewards();
      const delegationPenaltyBefore = await this.stakers.delegationEarlyWithdrawalPenalty(addr, stakerID);

      if (isDelegator) {
        await this.stakers.claimDelegationRewards(1, stakerID, {from: addr});
      } else {
        await this.stakers.claimValidatorRewards(1, {from: addr});
      }

      let rewardsAll = expectation.lockupExtraReward.add(expectation.lockupBaseReward).add(expectation.unlockedReward);
      const balanceStakersAfter = await balance.current(this.stakers.address);
      expect(balanceStakersAfter).to.be.bignumber.equal(balanceStakersBefore.sub(rewardsAll));

      const totalBurntLockupRewardsAfter = await this.stakers.totalBurntLockupRewards();
      expect(totalBurntLockupRewardsAfter).to.be.bignumber.equal(totalBurntLockupRewardsBefore.add(expectation.burntReward));
      const delegationPenaltyAfter = await this.stakers.delegationEarlyWithdrawalPenalty(addr, stakerID);
      if (isDelegator) {
        const penalty = expectation.lockupBaseReward.div(new BN(2)).add(expectation.lockupExtraReward);
        expect(delegationPenaltyAfter).to.be.bignumber.equal(delegationPenaltyBefore.add(penalty));
      } else {
        expect(delegationPenaltyAfter).to.be.bignumber.equal(delegationPenaltyBefore);
      }
    };

    it('should claim lockup rewards', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('1.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('5.0')});

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('292'));
      await expectRevert(this.stakers.lockUpStake(duration, { from: firstStaker }), "feature was not activated");
      await expectRevert(this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor }), "feature was not activated");
      // start LockedUp
      const sfc_owner = firstStaker;
      const currentEpoch = await this.stakers.currentEpoch.call();
      expect(currentEpoch).to.be.bignumber.equal(new BN("2"));
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration.add(new BN("5")), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3

      // locking has ended
      time.increase(duration.add(new BN('10')));
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #4

      //console.log(await this.stakers.calcValidatorLockupRewards(firstStakerID, 1, 1));
      //console.log(await this.stakers.calcDelegationLockupRewards(firstDepositor, firstStakerID, 1, 1));
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.000000291666666666'),
        lockupBaseReward: ether('0.0'),
        lockupExtraReward: ether('0.0'),
        burntReward: ether('0.0'),
        epoch: new BN('1')
      });
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.000000087499999999'),
        lockupBaseReward: ether('0.0'),
        lockupExtraReward: ether('0.0'),
        burntReward: ether('0.000000204166666667'),
        epoch: new BN('2')
      });
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.000000087499999999'),
        lockupExtraReward: ether('0.000000163333333332'),
        burntReward: ether('0.000000040833333335'),
        epoch: new BN('3')
      });
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.000000087499999999'),
        lockupBaseReward: ether('0.0'),
        lockupExtraReward: ether('0.0'),
        burntReward: ether('0.000000204166666667'),
        epoch: new BN('4')
      });

      await checkClaimReward(firstDepositor, firstStakerID, true, {
        unlockedReward: ether('0.000000708333333333'),
        lockupBaseReward: ether('0.0'),
        lockupExtraReward: ether('0.0'),
        burntReward: ether('0.0'),
        epoch: new BN('1')
      });
      await checkClaimReward(firstDepositor, firstStakerID, true, {
        unlockedReward: ether('0.000000212499999999'),
        lockupBaseReward: ether('0.0'),
        lockupExtraReward: ether('0.0'),
        burntReward: ether('0.000000495833333334'),
        epoch: new BN('2')
      });
      await checkClaimReward(firstDepositor, firstStakerID, true, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.000000212499999999'),
        lockupExtraReward: ether('0.000000396666666666'),
        burntReward: ether('0.000000099166666668'),
        epoch: new BN('3')
      });
      await checkClaimReward(firstDepositor, firstStakerID, true, {
        unlockedReward: ether('0.000000212499999999'),
        lockupBaseReward: ether('0.0'),
        lockupExtraReward: ether('0.0'),
        burntReward: ether('0.000000495833333334'),
        epoch: new BN('4')
      });

      // increase stake
      await this.stakers.increaseStake({ from: firstStaker, value: ether('2.0') });
      await this.stakers.increaseDelegation(firstStakerID, { from: firstDepositor, value: ether('2.0') });

      // lockup again
      await this.stakers.lockUpStake(duration.add(new BN("10005")), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #5
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.0000001215'),
        lockupExtraReward: ether('0.000000226889910000'),
        burntReward: ether('0.000000056610090000'),
        epoch: new BN('5')
      });
      await checkClaimReward(firstDepositor, firstStakerID, true, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.0000001785'),
        lockupExtraReward: ether('0.0000003332'),
        burntReward: ether('0.0000000833'),
        epoch: new BN('5')
      });

      // partial withdrawal
      const wrID1 = new BN('1');
      await this.stakers.prepareToWithdrawDelegationPartial(wrID1, firstStakerID, ether('1.0'), { from: firstDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #6
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.000000129999999999'),
        lockupExtraReward: ether('0.000000242762866666'),
        burntReward: ether('0.000000060570466668'),
        epoch: new BN('6')
      });
      await checkClaimReward(firstDepositor, firstStakerID, true, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.000000169999999999'),
        lockupExtraReward: ether('0.000000317333333332'),
        burntReward: ether('0.000000079333333335'),
        epoch: new BN('6')
      });

      // full withdrawal
      await this.stakers.prepareToWithdrawDelegation(firstStakerID, { from: firstDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #7
      await checkClaimReward(firstStaker, firstStakerID, false, {
        unlockedReward: ether('0.0'),
        lockupBaseReward: ether('0.0000003'),
        lockupExtraReward: ether('0.000000560222'),
        burntReward: ether('0.000000139778'),
        epoch: new BN('7')
      });
      await expectRevert(this.stakers.claimDelegationRewards(1, firstStakerID, { from: firstDepositor }), "delegation is deactivated");
    });

    it('should claim compound rewards', async () => {
      await this.stakers._createStake({
        from: firstStaker,
        value: ether('1.0')
      });
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {
        from: firstDepositor,
        value: ether('5.0')
      });

      await this.stakers.makeEpochSnapshots(10000000000, false); // epoch #1

      const delRewards1 = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, 0, 1);
      expect(delRewards1[0]).to.be.bignumber.equal(ether('0.708333333333333333'));
      const delCompRewards1 = await this.stakers.calcDelegationCompoundRewards(firstDepositor, firstStakerID, 0, 1);
      expect(delCompRewards1[0]).to.be.bignumber.equal(ether('0.708333333333333333'));
      const valRewards1 = await this.stakers.calcValidatorRewards(firstStakerID, 0, 1);
      expect(valRewards1[0]).to.be.bignumber.equal(ether('0.291666666666666666'));
      const valCompRewards1 = await this.stakers.calcValidatorCompoundRewards(firstStakerID, 0, 1);
      expect(valCompRewards1[0]).to.be.bignumber.equal(ether('0.291666666666666666'));

      await this.stakers.makeEpochSnapshots(10000000000, false); // epoch #2

      const delRewards2 = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, 0, 2);
      expect(delRewards2[0]).to.be.bignumber.equal(ether('1.416666666666666666'));
      const delCompRewards2 = await this.stakers.calcDelegationCompoundRewards(firstDepositor, firstStakerID, 0, 2);
      expect(delCompRewards2[0]).to.be.bignumber.equal(ether('1.431625258799171842'));
      const valRewards2 = await this.stakers.calcValidatorRewards(firstStakerID, 0, 2);
      expect(valRewards2[0]).to.be.bignumber.equal(ether('0.583333333333333332'));
      const valCompRewards2 = await this.stakers.calcValidatorCompoundRewards(firstStakerID, 0, 2);
      expect(valCompRewards2[0]).to.be.bignumber.equal(ether('0.616169977924944811'));

      await this.stakers.makeEpochSnapshots(10000000000, false); // epoch #3

      const delRewards3 = await this.stakers.calcDelegationRewards(firstDepositor, firstStakerID, 0, 3);
      expect(delRewards3[0]).to.be.bignumber.equal(ether('2.124999999999999999'));
      const delCompRewards3 = await this.stakers.calcDelegationCompoundRewards(firstDepositor, firstStakerID, 0, 3);
      expect(delCompRewards3[0]).to.be.bignumber.equal(ether('2.167249201019134371'));
      const valRewards3 = await this.stakers.calcValidatorRewards(firstStakerID, 0, 3);
      expect(valRewards3[0]).to.be.bignumber.equal(ether('0.874999999999999998'));
      const valCompRewards3 = await this.stakers.calcValidatorCompoundRewards(firstStakerID, 0, 3);
      expect(valCompRewards3[0]).to.be.bignumber.equal(ether('0.973804377557926418'));

      // claim
      const balanceStakersBefore = await balance.current(this.stakers.address);

      await this.stakers.claimDelegationCompoundRewards(3, firstStakerID, {from: firstDepositor});
      await this.stakers.claimValidatorCompoundRewards(3, {from: firstStaker});

      const balanceStakersAfter = await balance.current(this.stakers.address);
      expect(balanceStakersAfter).to.be.bignumber.equal(balanceStakersBefore); // no FTM were sent

      const firstDepositionInfo = await getDeposition(firstDepositor, firstStakerID);
      expect(firstDepositionInfo.amount).to.be.bignumber.equal(ether('7.167249201019134371'));
      const firstStakerInfo = await getStaker(firstStakerID);
      expect(firstStakerInfo.stakeAmount).to.be.bignumber.equal(ether('1.973804377557926418'));
      expect(firstStakerInfo.delegatedMe).to.be.bignumber.equal(ether('7.167249201019134371'));
      expect(await this.stakers.delegationsTotalAmount()).to.be.bignumber.equal(ether('7.167249201019134371'));
      expect(await this.stakers.stakeTotalAmount()).to.be.bignumber.equal(ether('1.973804377557926418'));
    });

    it('should claim compound rewards epoch-by-epoch', async () => {
      await this.stakers._createStake({
        from: firstStaker,
        value: ether('1.0')
      });
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {
        from: firstDepositor,
        value: ether('5.0')
      });

      // claim
      const balanceStakersBefore = await balance.current(this.stakers.address);

      for (let i = 0; i < 3; i++) {
        await this.stakers.makeEpochSnapshots(10000000000, false);
        await this.stakers.claimDelegationCompoundRewards(1, firstStakerID, {from: firstDepositor});
        await this.stakers.claimValidatorCompoundRewards(1, {from: firstStaker});
      }

      const balanceStakersAfter = await balance.current(this.stakers.address);
      expect(balanceStakersAfter).to.be.bignumber.equal(balanceStakersBefore); // no FTM were sent

      const firstDepositionInfo = await getDeposition(firstDepositor, firstStakerID);
      expect(firstDepositionInfo.amount).to.be.bignumber.equal(ether('7.081646205357142856'));
      const firstStakerInfo = await getStaker(firstStakerID);
      expect(firstStakerInfo.stakeAmount).to.be.bignumber.equal(ether('1.918353794642857141'));
      expect(firstStakerInfo.delegatedMe).to.be.bignumber.equal(ether('7.081646205357142856'));
      expect(await this.stakers.delegationsTotalAmount()).to.be.bignumber.equal(ether('7.081646205357142856'));
      expect(await this.stakers.stakeTotalAmount()).to.be.bignumber.equal(ether('1.918353794642857141'));
    });
  });
});
