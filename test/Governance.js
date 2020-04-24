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

contract('Governance test', async ([acc1, acc2, contractAddr]) => {
    beforeEach(async () => {
        this.firstEpoch = 0;
        this.stakers = await UnitTestStakers.new(this.firstEpoch);
        this.governance = await Governance.new(this.stakers.address);
    })

    it('checking proposal creation', async () => {
        // console.log(Governance);
        let validTitle = "title";
        let validDescription = "description";
        let version = "1.00";

        let validProposalMsg = {from: acc1, value: ether('2.0')}; //ether('2.0')
        await this.governance.addNewSoftwareVersion(version, contractAddr);
        let versions = await this.governance.getVersionDescription(version);
        expect(versions[0]).to.be.equal(version);

        await this.governance.createSoftwareUpgradeProposal(validTitle, validDescription, version, validProposalMsg);
        let proposalInfo = await this.governance.getProposal.call(1);
        expect(proposalInfo[6]).to.be.equal(validTitle);
        expect(proposalInfo[7]).to.be.equal(validDescription);
    })

    it('check depositing', async () => {
        // console.log(Governance);
        let validTitle = "title";
        let validDescription = "description";
        let version = "1.00";

        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};
        await this.governance.addNewSoftwareVersion(version, contractAddr);
        await this.governance.createSoftwareUpgradeProposal(validTitle, validDescription, version, createMsg);
        await expectRevert(this.governance.vote(1, 1, voteMsg), "proposal is not at voting period");
    })

    it('check voting', async () => {
        // console.log(Governance);
        let validTitle = "title";
        let validDescription = "description";
        let version = "1.00";

        let createMsg = {from: acc1, value: ether('2.0')};
        let voteMsg = {from: acc1};
        await this.stakers._createStake({from: acc1, value: ether('2.0')});
        await this.governance.addNewSoftwareVersion(version, contractAddr);
        await this.governance.createSoftwareUpgradeProposal(validTitle, validDescription, version, createMsg);
        await expectRevert(this.governance.vote(1, 1, voteMsg), "proposal is not at voting period");
        await this.governance.vote(1, 1);
    })
})
