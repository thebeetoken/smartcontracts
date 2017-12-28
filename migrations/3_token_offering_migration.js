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

var abi = require('ethereumjs-abi');


module.exports = function(deployer, network, accounts) {
    //console.log("Accounts: " + accounts);
    deployer.deploy(BeeToken);
    deployer.link(BeeToken, StandardToken);
    deployer.link(BeeToken, Ownable);
    deployer.link(BeeToken, BurnableToken);
    deployer.link(BeeToken, SafeMath);

    var startTime = "";
    var admin = "";
    var beneficiary = "";
    var rate = "";
    var baseCap = "";

    if(network == "ropsten") {
        admin = "0x1B0A74bdc6f278e550F6574C19ec75D8A4B82A2e";
        beneficiary = "0x1B0A74bdc6f278e550F6574C19ec75D8A4B82A2e";
        rate = 5000;
        baseCap = 5;
    }
    /*else if(network == "live"){
        admin = 
        beneficiary = 
        rate = ;
        baseCap = ;
    }*/
    else { // "localhost" or "coverage"
        admin = accounts[1];
        beneficiary = accounts[1];
        rate = 5000;
        baseCap = 5;
    }

    console.log("Admin: " + admin);
    console.log("Beneficiary: " + beneficiary);

    var abi_constructor_args_for_token = abi.rawEncode([ "address"],
        [admin]).toString('hex');
    console.log("------------------------------------------");
    console.log("Use the following line for the BeeToken constructor arguments on etherscan:");
    console.log(abi_constructor_args_for_token);
    console.log("------------------------------------------");

    //used to be accounts[1] for both token and sale
    deployer.deploy(BeeToken, admin).then(function() {
        var abi_constructor_args_for_sale = abi.rawEncode([ "uint", "address", "uint", "address" ],
        [ rate, beneficiary, baseCap, BeeToken.address]).toString('hex');
        console.log("------------------------------------------");
        console.log("Use the following line for the BeeTokenOffering constructor arguments on etherscan:");
        console.log(abi_constructor_args_for_sale);
        console.log("------------------------------------------");

        return deployer.deploy(BeeTokenOffering, rate, beneficiary, baseCap, BeeToken.address);
    });



};