const TestToken1 = artifacts.require("TestToken1");
const Staker = artifacts.require("Staker");

module.exports = function (deployer) {
  deployer.deploy(TestToken1).then(function() {
    return deployer.deploy(Staker, TestToken1.address);
  })
};