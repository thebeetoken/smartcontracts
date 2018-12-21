const TestToken = artifacts.require("TestToken");
const BeeArbitration = artifacts.require("BeeArbitration");
const BeePayment = artifacts.require("BeePayment");

function parameterize(network) {
  switch (network) {
  case 'ropsten': // Ropsten
    return {
      token: 0x7fffac23d59d287560dfeca7680b5393426cf503,
    };
  case 'development':
  case 'coverage':
    return {
      token: TestToken.address,
    };
  };
}


module.exports = function(deployer, network, accounts) {
  const parameters = parameterize(network);
  deployer.deploy(
    BeePayment,
    parameters.token, 
    '0x0' //gonna have to use the set arbitration address function 
    //parameters.arbitrationAddress 
  );

};


