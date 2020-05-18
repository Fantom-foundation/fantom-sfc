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
const IS_ACTIVE = 0;
const IS_FROSEN = 1;
const IS_VOTING = 5;
const IS_FAILED = 4;

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
            this.governance.createProposal(this.proposal.address, IS_FROSEN, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], validProposalMsg),
            'starting deposit is not enough',
        );
    });

    it('create proposal - valid', async () => {
        let validProposalMsg = {from: acc1, value: ether('1.0')}; //ether('2.0')

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], validProposalMsg);
    });

    it('check vote - proposal with a given id doesnt exist', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, IS_ACTIVE, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.vote(2, [new String("0x0000000000000").valueOf()], voteMsg), "proposal with a given id doesnt exist");
    });

    it('check vote - proposal is not at voting period', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, IS_FAILED, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.vote(1, [new String("0x0000000000000").valueOf()], voteMsg), "proposal is not at voting period");
    });

    // is not ok - first vote must be returned exception(this account has already voted. try to cancel a vote if you want to revote)
    it('check vote - this account has already voted. try to cancel a vote if you want to revote', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};
        const proposalID = 1;

        await this.governance.createProposal(this.proposal.address, IS_VOTING, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], createMsg);
        let voter = await this.governance.voters.call(acc1, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN('0'));

        let proposalStatus = await this.governance.getProposalStatus(proposalID);
        await expect(proposalStatus).to.be.bignumber.equal(new BN('5'));

        await this.governance.vote(proposalID, [new String("0x0000000000000").valueOf()], voteMsg);
        voter = await this.governance.voters.call(acc1, proposalID);
        await expect(voter.power).to.be.bignumber.equal(new BN('1'));

        await expectRevert(this.governance.vote(proposalID, [new String("0x0000000000000").valueOf()], voteMsg), "this account has already voted. try to cancel a vote if you want to revote");
    });

    it('check increase proposal deposit - proposal with a given id doesnt exist', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, IS_FAILED, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.increaseProposalDeposit(2, voteMsg), "proposal with a given id doesnt exist");
    });

    it('check increase proposal deposit - proposal is not depositing', async () => {
        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};

        await this.governance.createProposal(this.proposal.address, IS_FAILED, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], createMsg);

        await expectRevert(this.governance.increaseProposalDeposit(1, voteMsg), "proposal is not depositing");
    });

    // it('check increase proposal deposit - msg.value is zero', async () => {
    //     let createMsg = {from: acc1, value: ether('2.0')};
    //     let voteMsg = {from: acc1};
    //
    //     await this.governance.createProposal(this.proposal.address, IS_VOTING, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], createMsg);
    //
    //     await expectRevert(this.governance.increaseProposalDeposit(1, voteMsg), "msg.value is zero");
    // });
})
