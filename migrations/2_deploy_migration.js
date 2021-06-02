const PolCoin = artifacts.require("PolCoin");
const Staker = artifacts.require("Staker");

module.exports = function (deployer) {
  deployer.deploy(PolCoin).then(function() {
    return deployer.deploy(Staker, PolCoin.address);
  })
};