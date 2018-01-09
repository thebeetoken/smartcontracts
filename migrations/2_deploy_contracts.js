var BeeToken = artifacts.require("./BeeToken.sol");
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeePayments = artifacts.require("./BeePayments.sol");

module.exports = function(deployer, network, accounts) {
    console.log("Accounts: " + accounts);

    var beeToken = null;
    var beeOffering = null;
    var beePayments = null;

    return deployer.deploy(BeeToken, {from: accounts[1], gas: 4700000}).then(() => {
        return BeeToken.deployed().then(instance => {
            beeToken = instance;
        });
    }).then(() => {
        return deployer.deploy(BeeTokenOffering, 2000, accounts[1], 20000, beeToken.address, {from: accounts[1], gas: 4700000}).then(() => {
            return BeeTokenOffering.deployed().then(instance => {
                beeOffering = instance;
            });
        })
    }).then(() => {
        return deployer.deploy(BeePayments, accounts[0], {from: accounts[0], gas: 4700000}).then(() => {
            return BeePayments.deployed().then(instance => {
                beePayments = instance;
            })
        })
    });
};