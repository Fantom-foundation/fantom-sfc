const LRC = artifacts.require("LRC");
const Governance = artifacts.require("TestGovernance");
const GovernanceProd = artifacts.require("Governance");
const TestStakers = artifacts.require("TestStakers");
const UnitTestProposal = artifacts.require("UnitTestProposal");
const UpgradeabilityProxy = artifacts.require('UpgradeabilityProxy');
const ProposalFactory = artifacts.require('TestProposalFactory');
const DummySoftwareContract = artifacts.require('DummySoftwareContract');
const DummySoftwareUpgradeProposal = artifacts.require('DummySoftwareUpgradeProposal');

module.exports = async(deployer, network) => {
  await deployer.deploy(LRC);
  await deployer.link(LRC, Governance);
  await deployer.link(LRC, GovernanceProd);

  await deployer.deploy(TestStakers);
  await deployer.deploy(UpgradeabilityProxy);
  await deployer.deploy(DummySoftwareContract);
  const dummyAddress = DummySoftwareContract.address;

  await deployer.deploy(ProposalFactory, UpgradeabilityProxy.address);
  await deployer.deploy(Governance, TestStakers.address, ProposalFactory.address);
  await deployer.deploy(GovernanceProd, TestStakers.address, ProposalFactory.address);
  await deployer.deploy(DummySoftwareUpgradeProposal, dummyAddress, dummyAddress);
  // await deployer.deploy(UnitTestProposal);
};
