const TestToken = artifacts.require("TestToken");

module.exports = function (deployer, network, accounts) {
  // Deploy to Ganache only.
  if (['development', 'coverage'].includes(network)) {
    deployer.deploy(TestToken, '0', '0x0'); // Zero token supply; mint to test.
  }
};
