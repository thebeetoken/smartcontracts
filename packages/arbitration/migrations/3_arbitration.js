const TestToken = artifacts.require("TestToken");
const BeeArbitration = artifacts.require("BeeArbitration");

function parameterize(network) {
  switch (network) {
  case 'ropsten': // Ropsten
    return {
      token: 0x7fffac23d59d287560dfeca7680b5393426cf503
    };
  case 'development':
  case 'coverage':
    return {
      token: TestToken.address
    };
  };
}

module.exports = function(deployer, network, accounts) {
  const parameters = parameterize(network);
  deployer.deploy(
    BeeArbitration,
    parameters.token,
    {gas: 8000000 }
    //{from: parameters.arbitrationContractOwner,  gas: 8000000 }
  );
};


