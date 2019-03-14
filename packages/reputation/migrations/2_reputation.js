const BeeReputation = artifacts.require("BeeReputation");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(
    BeeReputation,
    {gas: 8000000 }
    //{from: parameters.arbitrationContractOwner,  gas: 8000000 }
  );
};


