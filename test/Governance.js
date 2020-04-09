const {
    BN,
    ether,
    expectRevert,
    time,
    balance,
} = require('openzeppelin-test-helpers');
const {expect} = require('chai');

const Governance = artifacts.require('Governance');

contract('Governance test', async ([acc1, acc2]) => {
    beforeEach(async () => {

        this.governance = await Governance.new();
    })

    it('check create proposal', async () => {
        // console.log(Governance);
        this.governance.createSoftwareUpgradeProposal("asd", "1.13", 100)
    })
})
