const TestToken = artifacts.require("TestToken");
const TestArbitration = artifacts.require("TestArbitration");

module.exports = function (deployer, network, accounts) {
  // Deploy to Ganache only.
  if (['development', 'coverage'].includes(network)) {
    deployer.deploy(TestArbitration);
    deployer.deploy(TestToken, '0', '0x0'); // Zero token supply; mint to test.
  }
};
