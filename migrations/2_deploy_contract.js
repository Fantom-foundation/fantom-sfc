const Stakers = artifacts.require('Stakers');

module.exports = (deployer) => {
  deployer.deploy(Stakers);
};
