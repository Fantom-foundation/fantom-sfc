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

contract('Governance test', async ([acc1, acc2, contractAddr]) => {
    beforeEach(async () => {
        this.firstEpoch = 0;
        this.stakers = await UnitTestStakers.new(this.firstEpoch);
        this.governance = await Governance.new(this.stakers.address);
        this.proposal = await UnitTestProposal.new();
    })

    it('create proposal', async () => {
        // console.log(Governance);
        let validTitle = "title";
        let validDescription = "description";
        let version = "1.00";

        let validProposalMsg = {from: acc1, value: ether('2.0')}; //ether('2.0')

        this.proposal.addSoftwareVersion(version, contractAddr);
        this.proposal.setUpgradableContract(contractAddr);

        this.proposal.resolveSoftwareUpgrade(version);

        await this.governance.createProposal(contractAddr, 1, [new String("0x0000000000000").valueOf(), new String("0x00000000000001").valueOf()], validProposalMsg);
    })

    it('check depositing', async () => {
        // console.log(Governance);
        let validTitle = "title";
        let validDescription = "description";
        let version = "1.00";

        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};
        await this.sowftwareUpdateProposal.addSoftwareVersion(version, contractAddr);
        // await this.governance.createSoftwareUpgradeProposal(validTitle, validDescription, version, createMsg);
        await expectRevert(this.governance.vote(1, [new String("0x627306090abaB").valueOf()], voteMsg), "proposal is not at voting period");
    })

    it('check voting', async () => {
        // console.log(Governance);
        let validTitle = "title";
        let validDescription = "description";
        let version = "1.00";

        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};
        await this.stakers._createStake({from: acc1, value: ether('2.0')});
        await this.sowftwareUpdateProposal.addSoftwareVersion(version, contractAddr);
        // await this.governance.createSoftwareUpgradeProposal(validTitle, validDescription, version, createMsg);
        await expectRevert(this.governance.vote(1, [new String("0x627306090abaB").valueOf()], voteMsg), "proposal is not at voting period");
        await this.governance.vote(1, 1);
    })
})
