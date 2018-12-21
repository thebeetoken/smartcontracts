const TestToken = artifacts.require("TestToken");
const TestArbitration = artifacts.require("TestArbitration");
const TokenPayments = artifacts.require("TokenPayments");

const ROPSTEN_BEETOKEN_ADDRESS = '0x7fffac23d59d287560dfeca7680b5393426cf503';

function parameterize(network) {
  switch (network) {
  case 'ropsten': // Ropsten
    return {
      token: ROPSTEN_BEETOKEN_ADDRESS,
      arbitration: '0x0',
      cancelPeriod: 60 * 60,
      disputePeriod: 60 * 60
    };
  case 'development':
  case 'coverage':
    return {
      token: TestToken.address,
      arbitration: TestArbitration.address,
      cancelPeriod: 5 * 60,
      disputePeriod: 10 * 60
    };
  };
}

module.exports = function(deployer, network, accounts) {
  const parameters = parameterize(network);

  deployer.deploy(
    TokenPayments,
    parameters.token,
    parameters.arbitration,
    parameters.cancelPeriod,
    parameters.disputePeriod
  );
};
