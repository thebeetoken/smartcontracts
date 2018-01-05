
var SafeMath = artifacts.require("./math/SafeMath.sol");
var ERC20 = artifacts.require("./token/ERC20.sol");
var ERC20Basic = artifacts.require("./token/ERC20Basic.sol");
var BurnableToken = artifacts.require("./token/BurnableToken.sol");
var BasicToken = artifacts.require("./token/BasicToken.sol");
var StandardToken = artifacts.require("./token/StandardToken.sol");
var Ownable = artifacts.require("./ownership/Ownable.sol");
var Pausable = artifacts.require("./lifecycle/Pausable.sol");
var BeeToken = artifacts.require("./BeeToken.sol");
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeePayments = artifacts.require("./BeePayments.sol");

module.exports = function(deployer, network, accounts) {
    console.log("Accounts: " + accounts);

    deployer.deploy(SafeMath);
    deployer.deploy(Ownable);
    deployer.link(Ownable, Pausable);
    deployer.deploy(Pausable);

    deployer.deploy(BasicToken);
    deployer.link(BasicToken, SafeMath);
    deployer.link(BasicToken, ERC20Basic);

    deployer.deploy(StandardToken);
    deployer.link(StandardToken, BasicToken);

    deployer.deploy(BeeToken);
    deployer.link(BeeToken, StandardToken);
    deployer.link(BeeToken, Ownable);
    deployer.link(BeeToken, BurnableToken);
    deployer.link(BeeToken, SafeMath);

    var time = new Date().getTime() / 1000;

    deployer.deploy(BeeToken, accounts[1]).then(function() {
        return deployer.deploy(BeeTokenOffering, 2000, accounts[1], 20000, BeeToken.address);
    });
    
    deployer.deploy(BeeToken, accounts[1]).then(function() {
        return deployer.deploy(BeePayments, accounts[0]);
    });
};
