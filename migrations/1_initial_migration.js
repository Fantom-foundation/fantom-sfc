const Migrations = artifacts.require("Migrations");
const Proposals = artifacts.require("Proposals");
const Governance = artifacts.require("Governance");

module.exports = async(deployer, network) => {
  await deployer.deploy(Proposals);
  await deployer.deploy(Governance);
  await deployer.deploy(Migrations);
};
