const {
    BN,
    ether,
    expectRevert,
    time,
    balance,
} = require('openzeppelin-test-helpers');
const {expect} = require('chai');



const Web3 = require('web3');
var web3 = new Web3();
web3.setProvider(Web3.givenProvider || 'ws://localhost:9545')//..Web3.givenProvider);

const Governance = artifacts.require('Governance'); // UnitTestGovernance .sol
const UnitTestStakers = artifacts.require('UnitTestStakers');
const UnitTestProposal = artifacts.require('UnitTestProposal');
const IS_VOTING = 5;
const stakerMetadata = "0x0001";

contract('Governance test', async ([acc1, acc2, contractAddr]) => {
    beforeEach(async () => {
        this.firstEpoch = 0;
        this.stakers = await UnitTestStakers.new(this.firstEpoch);
        this.governance = await Governance.new(this.stakers.address);
        this.proposal = await UnitTestProposal.new();
    });

    it('create proposal invalid - starting deposit is not enough', async () => {
        let validProposalMsg = {from: acc1, value: ether('0.0')}; //ether('2.0')
        await expectRevert(
            this.governance.createProposal(this.proposal.address, 1, 1,
                [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], validProposalMsg),
            'starting deposit is not enough',
        );
    });

    it('create proposal - valid', async () => {
        let validProposalMsg = {from: acc1, value: ether('1.0')}; //ether('2.0')

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], validProposalMsg);
    });

    it('create proposal - choises is empty', async () => {
        let validProposalMsg = {from: acc1, value: ether('1.0')}; //ether('2.0')

        await expectRevert(this.governance.createProposal(this.proposal.address, IS_VOTING, 1, [], validProposalMsg), "choises is empty")
    });

    it('check vote - proposal with a given id doesnt exist', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, 0, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.vote(2,
            [String("0x0000000000000").valueOf()], voteMsg), "proposal with a given id doesnt exist");
    });

    it('check vote - proposal is not at voting period', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, 4, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.vote(1,
            [String("0x0000000000000").valueOf()], voteMsg), "proposal is not at voting period");
    });

    it('check vote - this account has already voted', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);
        let voter = await this.governance.voters.call(acc1, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN('0'));

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], voteMsg);

        await expectRevert(this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], voteMsg),
            "this account has already voted. try to cancel a vote if you want to revote");
    });

    it('check vote - incorrect choises', async () => {
        let createMsg = {from: acc1, value: ether('1.0')};
        let voteMsg = {from: acc1};
        const proposalID = 1;

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.vote(proposalID, [String("0x0000000000001").valueOf()], voteMsg), "incorrect choises");
    });

    it('check vote - without staker create delegation', async () => {
        let createMsg = {from: acc1, value: ether('1.0')};
        let voteMsg = {from: acc1};
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], voteMsg);

        let voter = await this.governance.voters.call(acc1, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN(ether('3.0')));
    });

    it('check vote - with staker create delegation', async () => {
        const stakerID = 1;

        let createMsg = {from: acc1, value: ether('1.0')};
        let voteMsg = {from: acc1};
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createDelegation(stakerID, {from: acc2, value: ether('1.0')});

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], voteMsg);

        let voter = await this.governance.voters.call(acc1, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN(ether('4.0')));
    });

    it('check increase proposal deposit - proposal with a given id doesnt exist', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, 4, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.increaseProposalDeposit(2, voteMsg), "proposal with a given id doesnt exist");
    });

    it('check increase proposal deposit - proposal is not depositing', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, 4, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.increaseProposalDeposit(1, voteMsg), "proposal is not depositing");
    });

    it('check increase proposal deposit - msg.value is zero', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, 1, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.increaseProposalDeposit(1, voteMsg), "msg.value is zero");
    });

    it('check increase proposal deposit - correct', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1, value: ether('1.0')};
        const proposalID = 1;

        await this.governance.createProposal(this.proposal.address, 1, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], createMsg);
        await expect(await this.governance.depositors.call(acc1, proposalID)).to.be.bignumber.equal(ether('0.0'));

        await this.governance.increaseProposalDeposit(proposalID, voteMsg);
        await expect(await this.governance.depositors.call(acc1, proposalID)).to.be.bignumber.equal(ether('1.0'));
    });

    it('check handle deadlines - incorrect indexes passed', async () => {
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc2});

        await expectRevert(this.governance.handleDeadlines(3, 1), "incorrect indexes passed");
    });

    it('check handle deadlines - 2 deadlines', async () => {
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc2});

        let deadline = await this.governance.deadlines.call(0);
        await expect(deadline).to.be.bignumber.greaterThan(new BN('0'));

        let deadline1 = await this.governance.deadlines.call(1);
        await expect(deadline1).to.be.bignumber.greaterThan(new BN('0'));

        await this.governance.handleDeadlines(0, 2);
        let deadlinesCount = await this.governance.getDeadlinesCount();
        await expect(deadlinesCount).to.be.bignumber.equal(new BN('0'));
    });

    it('check handle deadlines - one deadline', async () => {
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc2});

        let deadline = await this.governance.deadlines.call(0);
        await expect(deadline).to.be.bignumber.greaterThan(new BN('0'));

        await this.governance.handleDeadlines(0, 1);
        let deadlinesCount = await this.governance.getDeadlinesCount();
        await expect(deadlinesCount).to.be.bignumber.equal(new BN('0'));
    });

    it('check handle deadlines - fail proposal', async () => {
        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, 3, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        await this.governance.handleDeadlines(0, 2);
        await expect(await this.governance.getProposalStatus(1)).to.be.bignumber.equal(new BN('2'));
    });

    it('check cancel vote', async () => {
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc2});


        await this.governance.cancelVote(proposalID, {from: acc1});

        let voter = await this.governance.voters.call(acc1, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN(ether('0.0')));
        await expect(voter.previousDelegation).to.be.equal("0x0000000000000000000000000000000000000000");

        voter = await this.governance.voters.call(acc2, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN(ether('4.0')));
        await expect(voter.previousDelegation).to.be.equal("0x0000000000000000000000000000000000000000");
    });

    it('check cancel vote - incorrect choises', async () => {
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc2});

        await expectRevert(this.governance.cancelVote(proposalID, {from: acc1}), "incorrect choises");
    });

    it('check lrc', async () => {
        const proposalID = 1;

        await this.stakers.createStake(stakerMetadata, {from: acc1, value: ether('3.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('1'));
        await this.stakers.createStake(stakerMetadata, {from: acc2, value: ether('4.0')});
        expect(await this.stakers.stakersNum.call()).to.be.bignumber.equal(new BN('2'));

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1, value: ether('1.0')});

        let lrcOptions = await this.governance.getProposalOption(proposalID, 1);
        let desc = String(lrcOptions[0]);
        let arc = lrcOptions[1];
        let dw = lrcOptions[2];
        let resist = lrcOptions[3];
        let totalVoites = lrcOptions[4];
        let maxPossibleVotes = lrcOptions[5];
        await expect(web3.utils.fromAscii(String(desc))).to.be.equal(String('0x0000000000000000000000000000000000000000000000000000000000000000').valueOf()); // lrc option description
        await expect(arc).to.be.bignumber.equal(new BN('0')); // arc
        await expect(dw).to.be.bignumber.equal(new BN('0'));
        await expect(resist).to.be.bignumber.equal(new BN('0'));
        await expect(totalVoites).to.be.bignumber.equal(new BN('0'));
        await expect(maxPossibleVotes).to.be.bignumber.equal(new BN('0'));

        let lrcOptions2 = await this.governance.getProposalOption(proposalID, 2);
        let desc2 = String(lrcOptions2[0]);
        let arc2 = lrcOptions2[1];
        let dw2 = lrcOptions2[2];
        let resist2 = lrcOptions2[3];
        let totalVoites2 = lrcOptions2[4];
        let maxPossibleVotes2 = lrcOptions2[5];
        await expect(web3.utils.fromAscii(String(desc2))).to.be.equal(String('0x0000000000000100000000000000000000000000000000000000000000000000').valueOf()); // lrc option description
        await expect(arc2).to.be.bignumber.equal(new BN('0')); // arc
        await expect(dw2).to.be.bignumber.equal(new BN('0'));
        await expect(resist2).to.be.bignumber.equal(new BN('0'));
        await expect(totalVoites2).to.be.bignumber.equal(new BN('0'));
        await expect(maxPossibleVotes2).to.be.bignumber.equal(new BN('0'));

        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc1});
        await this.governance.vote(proposalID,
            [String("0x0000000000000").valueOf(), String("0x00000000000001").valueOf()], {from: acc2});

        lrcOptions = await this.governance.getProposalOption(proposalID, 1);
        desc = String(lrcOptions[0]);
        arc = lrcOptions[1];
        dw = lrcOptions[2];
        resist = lrcOptions[3];
        totalVoites = lrcOptions[4];
        maxPossibleVotes = lrcOptions[5];
        await expect(web3.utils.fromAscii(String(desc))).to.be.equal(String('0x0000000000000000000000000000000000000000000000000000000000000000').valueOf()); // lrc option description
        await expect(arc).to.be.bignumber.equal(new BN('0')); // arc
        await expect(dw).to.be.bignumber.equal(new BN('0'));
        await expect(resist).to.be.bignumber.equal(new BN('0'));
        await expect(totalVoites).to.be.bignumber.equal(new BN(ether('7.0')));
        await expect(maxPossibleVotes).to.be.bignumber.equal(new BN('0'));

        lrcOptions2 = await this.governance.getProposalOption(proposalID, 2);
        desc2 = String(lrcOptions2[0]);
        arc2 = lrcOptions2[1];
        dw2 = lrcOptions2[2];
        resist2 = lrcOptions2[3];
        totalVoites2 = lrcOptions2[4];
        maxPossibleVotes2 = lrcOptions2[5];
        await expect(web3.utils.fromAscii(String(desc2))).to.be.equal(String('0x0000000000000100000000000000000000000000000000000000000000000000').valueOf()); // lrc option description
        await expect(arc2).to.be.bignumber.equal(new BN('0')); // arc
        await expect(dw2).to.be.bignumber.equal(new BN('0'));
        await expect(resist2).to.be.bignumber.equal(new BN(ether('7.0')));
        await expect(totalVoites2).to.be.bignumber.equal(new BN(ether('7.0')));
        await expect(maxPossibleVotes2).to.be.bignumber.equal(new BN('0'));

        await this.governance.handleDeadlines(0, 2);

        lrcOptions = await this.governance.getProposalOption(proposalID, 1);
        desc = String(lrcOptions[0]);
        arc = lrcOptions[1];
        dw = lrcOptions[2];
        resist = lrcOptions[3];
        totalVoites = lrcOptions[4];
        maxPossibleVotes = lrcOptions[5];
        await expect(web3.utils.fromAscii(String(desc))).to.be.equal(String('0x0000000000000000000000000000000000000000000000000000000000000000').valueOf()); // lrc option description
        await expect(arc).to.be.bignumber.equal(new BN('0')); // arc
        await expect(dw).to.be.bignumber.equal(new BN('0'));
        await expect(resist).to.be.bignumber.equal(new BN('0'));
        await expect(totalVoites).to.be.bignumber.equal(new BN(ether('7.0')));
        await expect(maxPossibleVotes).to.be.bignumber.equal(new BN('0'));

        lrcOptions2 = await this.governance.getProposalOption(proposalID, 2);
        desc2 = String(lrcOptions2[0]);
        arc2 = lrcOptions2[1];
        dw2 = lrcOptions2[2];
        resist2 = lrcOptions2[3];
        totalVoites2 = lrcOptions2[4];
        maxPossibleVotes2 = lrcOptions2[5];
        await expect(web3.utils.fromAscii(String(desc2))).to.be.equal(String('0x0000000000000100000000000000000000000000000000000000000000000000').valueOf()); // lrc option description
        await expect(arc2).to.be.bignumber.equal(new BN('2000')); // arc
        await expect(dw2).to.be.bignumber.equal(new BN('0'));
        await expect(resist2).to.be.bignumber.equal(new BN(ether('7.0')));
        await expect(totalVoites2).to.be.bignumber.equal(new BN(ether('7.0')));
        await expect(maxPossibleVotes2).to.be.bignumber.equal(new BN('0'));

    });
})
