const {
  BN,
  ether,
  expectRevert,
  time,
  balance,
} = require('openzeppelin-test-helpers');
const {expect} = require('chai');

const UnitTestStakers = artifacts.require('UnitTestStakers');
//const getDeposition = async (depositor, to) => this.stakers.delegations_v2.call(depositor, to);
const getDeposition = async (depositor, to) => this.stakers.delegations.call(depositor);
const getStaker = async (stakerID) => this.stakers.stakers.call(stakerID);

contract('SFC', async ([firstStaker, secondStaker, thirdStaker, firstDepositor, secondDepositor, thirdDepositor]) => {
  beforeEach(async () => {
    this.firstEpoch = 0;
    this.stakers = await UnitTestStakers.new(this.firstEpoch);
    this.validatorComission = new BN('150000'); // 0.15
  });

  describe ('Locking stake tests', async () => {
    it('should start \"locked stake\" feature', async () => {
      await this.stakers.makeEpochSnapshots(5);
      await this.stakers.makeEpochSnapshots(5);
      const sfc_owner = firstStaker; // first address from contract parameters
      const other_address = secondStaker;
      const currentEpoch = await this.stakers.currentEpoch.call();
      await expectRevert(this.stakers.startLockedUp(currentEpoch, { from: other_address }), "Ownable: caller is not the owner");
      await this.stakers.startLockedUp(currentEpoch.add(new BN('5')), { from: sfc_owner });
      expect(await this.stakers.firstLockedUpEpoch.call()).to.be.bignumber.equal(currentEpoch.add(new BN('5')));
      await expectRevert(this.stakers.startLockedUp(currentEpoch.sub((new BN('1'))), { from: sfc_owner }), "can't start in the past");
      await this.stakers.startLockedUp(currentEpoch, { from: sfc_owner });
      expect(await this.stakers.firstLockedUpEpoch.call()).to.be.bignumber.equal(currentEpoch);
      await this.stakers.makeEpochSnapshots(5);
      await this.stakers.makeEpochSnapshots(5);
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

      await this.stakers.lockUpStake(duration, { from: firstStaker });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #5
      epoch = new BN('5');

      // locked up staker receives 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
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
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));

      // first locking has ended
      time.increase(86400 * 14 - 9999);
      await this.stakers.makeEpochSnapshots(); // epoch #7
      epoch = new BN('8');
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #8
      // locked up stakers receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));

      // second locking is still active
      epoch = new BN('9');
      time.increase(10002);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #9
      // locked up stakers receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000052631578947'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000051315789473'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));

      // second locking has ended
      epoch = new BN('10');
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #10
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
      await this.stakers.lockUpStake(maxDuration, { from: firstStaker });
    });

    it('should not call prepareToWithdrawStake, until locked time is pass', async () => {
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

    it('should not call prepareToWithdrawStakePartial, until locked time is pass', async () => {
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

      await this.stakers.lockUpStake(duration, { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #5
      epoch = new BN('5');

      // locked up stakers/delegators receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000223684210526'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000134210526315'));

      time.increase(10000);
      await expectRevert(this.stakers.lockUpDelegation(duration, firstStakerID, { from: thirdDepositor }), "staker's locking will finish first");
      await this.stakers.lockUpStake(duration, { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: thirdDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #6
      epoch = new BN('6');
      // locked up stakers/delegators receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000223684210526'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000447368421052'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));

      // first locking has ended
      time.increase(86400 * 14 - 9999);
      await this.stakers.makeEpochSnapshots(); // epoch #7
      epoch = new BN('8');
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #8
      // locked up stakers/delegators receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000447368421052'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));

      // second locking is still active
      epoch = new BN('9');
      time.increase(10002);
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #9
      // locked up stakers/delegators receive 100% reward
      expect(await this.stakers.calcValidatorEpochReward(firstStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000171052631578'));
      expect(await this.stakers.calcDelegationEpochReward(thirdDepositor, firstStakerID, epoch, ether('10.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000447368421052'));
      // reduce reward by 70% for unlocked stakers/delegators
      expect(await this.stakers.calcDelegationEpochReward(firstDepositor, firstStakerID, epoch, ether('5.0'), this.validatorComission)).to.be.bignumber.equal(ether('0.000000067105263157'));
      expect(await this.stakers.calcValidatorEpochReward(secondStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000015789473684'));
      expect(await this.stakers.calcValidatorEpochReward(thirdStakerID, epoch, this.validatorComission)).to.be.bignumber.equal(ether('0.000000031578947368'));

      // second locking has ended
      epoch = new BN('10');
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #10
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
      await this.stakers.lockUpStake(minDuration.mul(new BN("2")), { from: secondStaker });

      await expectRevert(this.stakers.lockUpDelegation(minDuration.sub(new BN("1")), secondStakerID, { from: firstDepositor }), "incorrect duration");
      await this.stakers.lockUpDelegation(minDuration, secondStakerID, { from: firstDepositor });
      await expectRevert(this.stakers.lockUpDelegation(maxDuration.add(new BN("1")), firstStakerID, { from: secondDepositor }), "incorrect duration");
      await this.stakers.lockUpDelegation(maxDuration.sub(new BN("1")), firstStakerID, { from: secondDepositor });
      await expectRevert(this.stakers.lockUpDelegation(minDuration, firstStakerID, { from: secondDepositor }), "already locked up");
      await expectRevert(this.stakers.lockUpDelegation(minDuration.mul(new BN("3")), secondStakerID, { from: firstDepositor }), "staker's locking will finish first");
      await this.stakers.lockUpDelegation(minDuration.add(new BN("2")), secondStakerID, { from: firstDepositor });
    });

    it('should subtract penalty if prepareToWithdrawDelegation will call earlier than locked time is pass', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('10.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('1.0')});
      await this.stakers.createDelegation(firstStakerID, {from: secondDepositor, value: ether('1.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('14'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration.add(new BN('5')), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: secondDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3

      await this.stakers.claimDelegationRewards(2, {from: firstDepositor});
      const penaltyNonLocked = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penaltyNonLocked).to.be.bignumber.equal(ether('0.0')); // penalty must be zero for non-lockup epochs

      const reward = await this.stakers.calcDelegationRewards(firstDepositor, 0, 1);
      expect(reward[0]).to.be.bignumber.equal(ether('0.000000070833333333'));
      await this.stakers.claimDelegationRewards(100, {from: firstDepositor});
      await this.stakers.claimDelegationRewards(100, {from: secondDepositor});
      const penalty = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penalty).to.be.bignumber.equal(ether('0.000000060208333333')); // (50% of base reward + 100% of extra reward) * 1.0 FTM / 1.0 FTM

      time.increase(86400 * 14 - 2); // not unlocked yet

      await this.stakers.prepareToWithdrawDelegation({ from: firstDepositor });
      const firstDeposition = await getDeposition(firstDepositor, firstStakerID);
      expect(firstDeposition.amount).to.be.bignumber.equal(ether('1.0').sub(penalty));

      time.increase(3); // after lockup

      await this.stakers.prepareToWithdrawDelegation({ from: secondDepositor });
      const secondDeposition = await getDeposition(secondDepositor, firstStakerID);
      expect(secondDeposition.amount).to.be.bignumber.equal(ether('1.0'));
    });

    it('should subtract penalty if prepareToWithdrawDelegationPartial will call earlier than locked time is pass', async () => {
      await this.stakers._createStake({from: firstStaker, value: ether('20.0')});
      let firstStakerID = await this.stakers.getStakerID(firstStaker);
      await this.stakers.createDelegation(firstStakerID, {from: firstDepositor, value: ether('2.0')});
      await this.stakers.createDelegation(firstStakerID, {from: secondDepositor, value: ether('2.0')});
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #1

      const duration = (new BN('86400')).mul(new BN('14'));
      // start LockedUp
      const sfc_owner = firstStaker;
      const startLockedUpEpoch = new BN("2");
      await this.stakers.startLockedUp(startLockedUpEpoch, { from: sfc_owner });

      await this.stakers.makeEpochSnapshots(10000, false); // epoch #2

      await this.stakers.lockUpStake(duration.add(new BN('5')), { from: firstStaker });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: firstDepositor });
      await this.stakers.lockUpDelegation(duration, firstStakerID, { from: secondDepositor });
      await this.stakers.makeEpochSnapshots(10000, false); // epoch #3

      await this.stakers.claimDelegationRewards(2, {from: firstDepositor});
      const penaltyNonLocked = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penaltyNonLocked).to.be.bignumber.equal(ether('0.0')); // penalty must be zero for non-lockup epochs

      const reward = await this.stakers.calcDelegationRewards(firstDepositor, 0, 1);
      expect(reward[0]).to.be.bignumber.equal(ether('0.000000070833333333'));
      await this.stakers.claimDelegationRewards(100, {from: firstDepositor});
      await this.stakers.claimDelegationRewards(100, {from: secondDepositor});
      const penalty = await this.stakers.calcDelegationPenalty(firstDepositor, firstStakerID, ether('1.0'));
      expect(penalty).to.be.bignumber.equal(ether('0.000000030104166666')); // (50% of base reward + 100% of extra reward) * 1.0 FTM / 2.0 FTM

      time.increase(86400 * 14 - 2); // not unlocked yet

      const wrID1 = new BN('1');
      await this.stakers.prepareToWithdrawDelegationPartial(wrID1, ether('1.0'), { from: firstDepositor });
      const firstDeposition = await getDeposition(firstDepositor, firstStakerID);
      const firstRequest = await this.stakers.withdrawalRequests(firstDepositor, wrID1);
      expect(firstDeposition.amount).to.be.bignumber.equal(ether('1.0'));
      expect(firstRequest.amount).to.be.bignumber.equal(ether('1.0').sub(penalty));

      time.increase(3); // after lockup

      const wrID2 = new BN('2');
      await this.stakers.prepareToWithdrawDelegationPartial(wrID2, ether('1.0'), { from: secondDepositor });
      const secondDeposition = await getDeposition(secondDepositor, firstStakerID);
      const secondRequest = await this.stakers.withdrawalRequests(secondDepositor, wrID2);
      expect(secondDeposition.amount).to.be.bignumber.equal(ether('1.0'));
      expect(secondRequest.amount).to.be.bignumber.equal(ether('1.0'));
    });
  });
});