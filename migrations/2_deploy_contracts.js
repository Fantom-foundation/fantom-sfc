const LRC = artifacts.require("LRC");
const Governance = artifacts.require("Governance");
const TestStakers = artifacts.require("TestStakers");
const UnitTestProposal = artifacts.require("UnitTestProposal");

module.exports = async(deployer, network) => {
  await deployer.deploy(TestStakers);
  await deployer.deploy(LRC);
  await deployer.link(LRC, Governance);
  await deployer.deploy(Governance, TestStakers.address);
  await deployer.deploy(UnitTestProposal);
};
