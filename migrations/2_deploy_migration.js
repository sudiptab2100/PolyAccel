const Staker = artifacts.require("Staker");

module.exports = function (deployer) {
  deployer.deploy(Staker);
};