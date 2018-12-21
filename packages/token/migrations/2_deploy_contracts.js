const BeeToken = artifacts.require("./BeeToken.sol");
const BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");

module.exports = function (deployer, network, accounts) {
    console.log(`Accounts: ${accounts}`);

    let beeToken = null;
    let beeOffering = null;

    const owner = accounts[0];
    const admin = accounts[1];

    return deployer.deploy(
        BeeToken, admin, { from: owner }
    ).then(() => {
        return BeeToken.deployed().then(instance => {
            beeToken = instance;
            console.log(`BeeToken deployed at \x1b[36m${instance.address}\x1b[0m`)
        });
    }).then(() => {
        const rate = 5000;
        const beneficiary = accounts[1];
        const baseCap = 10**17;

        return deployer.deploy(
            BeeTokenOffering, rate, beneficiary, baseCap, beeToken.address, { from: owner }
        ).then(() => {
            return BeeTokenOffering.deployed().then(instance => {
                beeOffering = instance;
                console.log(`BeeTokenOffering deployed at \x1b[36m${instance.address}\x1b[0m`)

                beeToken.setTokenOffering(instance.address, 0);
            });
        })
    });
};
