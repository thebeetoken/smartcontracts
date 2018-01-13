
const BeeToken = artifacts.require("./BeeToken.sol");
const BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
const util = require('./util');
const BigNumber = web3.BigNumber;

const timeTravel = function (time) {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [time], // 86400 is num seconds in day
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err) }
            return resolve(result)
        });
    })
}

contract('BeeToken (Basic Tests)', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    const owner = accounts[0];
    const user1 = accounts[1];

    let token = null;
    let offering = null;

    beforeEach(async function () {
        token = await BeeToken.new(owner);
        offering = await BeeTokenOffering.new(
            1, token.address, 1000, token.address
        );
    });

    it("should have 18 decimal places", async function () {
        const decimals = await token.decimals();
        assert.equal(decimals, 18);
    });

    it("transferEnabled is initialized to false", async function () {
        const result = await token.transferEnabled();
        assert.equal(result, false);
    });

    it("should have an initial owner balance of 500 million tokens", async function () {
        const ownerBalance = (await token.balanceOf(owner)).toNumber();

        assert.equal(ownerBalance, new BigNumber("5e26"), "the owner balance should initially be 500 million tokens");
    });

    it("should not allow a regular user to transfer before they are enabled", async function () {
        await util.assertRevert(token.transfer(user1, 10, { from: user1 }));
    });

    it("should allow owner to set token offering", async function () {
        assert.equal(await token.tokenOfferingAddr(), '0x0000000000000000000000000000000000000000');
        await token.setTokenOffering(offering.address, 100);
        assert.equal(await token.tokenOfferingAddr(), offering.address);
    });

    it("should not allow non-owner to set token offering", async function () {
        assert.equal(await token.tokenOfferingAddr(), '0x0000000000000000000000000000000000000000');
        // user1 is not owner of token
        await util.assertRevert(token.setTokenOffering(offering.address, 100, { from: user1 }));
    });

    it("Once transfer is Enabled, cannot setTokenOffering", async function() {
        let transferEnabled = await token.transferEnabled();
        assert.isFalse(transferEnabled);
        await token.enableTransfer({from: owner});
        transferEnabled = await token.transferEnabled();
        assert.isTrue(transferEnabled);

        await util.assertRevert(token.setTokenOffering(offering.address, 100));
    });

    it("Token for sale cannot be greater than allowance", async function() {
        // offering allowance should be 1.5e26
        await util.assertRevert(token.setTokenOffering(offering.address, 2e26));
    });
    /*
    it("should allow the deployer (owner) of the token to make transfers", async function() {
        await token.transfer(offering.address, 10 ** 26);
        let ownerBalance = await token.balanceOf(owner);
        let offeringBalance = await token.balanceOf(offering.address);
        let initialSupply = await token.INITIAL_SUPPLY();
        let totalSupply = await token.totalSupply();
        ownerBalance = ownerBalance.toNumber();
        offeringBalance = offeringBalance.toNumber();
        initialSupply = initialSupply.toNumber();
        totalSupply = totalSupply.toNumber();
  
        assert.equal(ownerBalance, bigInt("4e26"), "the owner should now have 80% of the original funds");
        assert.equal(offeringBalance, bigInt("1e26"), "the token offering should now have 20% of the original funds");
        assert.equal(totalSupply, initialSupply, "the total supply should equal the initial supply");
    });
    */

    it("should not allow a regular user to enable transfers", async function () {
        await util.assertRevert(token.enableTransfer({ from: user1 }));
    });

    it("should enable transfers after invoking enableTransfer as owner", async function () {
        let isEnabledBefore = await token.transferEnabled();
        assert.isFalse(isEnabledBefore, "transfers should not be enabled");
        await token.enableTransfer();
        let isEnabledAfter = await token.transferEnabled();
        assert.isTrue(isEnabledAfter, "transfers should be enabled");
    });

});

contract('BeeToken (token burning tests)', function (accounts) {

    // account[0] points to the owner on the testRPC setup
    const owner = accounts[0];
    const user1 = accounts[1];

    let token = null;

    beforeEach(async function () {
        token = await BeeToken.new(owner);
    });

    it('Owner should be able to burn token whenever', async function () {
        const oldTotalSupply = new BigNumber(5e+26);
        const newTotalSupply = new BigNumber(5e+26 - 1e+3);

        const balance = await token.balanceOf(owner);
        assert.equal(balance.toNumber(), oldTotalSupply, 'old balance');
        const total = await token.totalSupply();
        assert.equal(total.toNumber(), oldTotalSupply, 'old total supply');

        const { logs } = await token.burn(10e+3, { from: owner });

        const newBalance = await token.balanceOf(owner);
        assert.equal(newBalance.toNumber(), newTotalSupply, 'new balance');
        const newTotal = await token.totalSupply();
        assert.equal(newTotal.toNumber(), newTotalSupply, 'new total supply');
    });


    it("non-owner should not be able to burn tokens when transfers are not enabled", async function () {
        let transferEnabled = await token.transferEnabled();
        assert.isFalse(transferEnabled);

        // Owner transfers 10 tokens to user1
        await token.transfer(user1, 10);
        let balance = await token.balanceOf(user1);
        assert.equal(balance, 10);

        // Recipient tries to burn 3 tokens when transfers are not enabled
        await util.assertRevert(token.burn(3, { from: user1 }));
    });

    it("non-owner should be able to burn tokens when transfers are enabled", async function () {
        let transferEnabled = await token.transferEnabled();
        assert.isFalse(transferEnabled);
        await token.enableTransfer()
        transferEnabled = await token.transferEnabled();
        assert.isTrue(transferEnabled);

        // Owner transfers 10 tokens to user1
        await token.transfer(user1, 10);
        let balance = await token.balanceOf(user1);
        assert.equal(balance, 10);

        await token.burn(3, { from: user1 });
        balance = await token.balanceOf(user1);
        assert.equal(balance, 7);
    });

    it("One cannot burn more tokens than balance", async function () {
        let transferEnabled = await token.transferEnabled();
        assert.isFalse(transferEnabled);
        await token.enableTransfer()
        transferEnabled = await token.transferEnabled();
        assert.isTrue(transferEnabled);

        // Owner transfers 10 tokens to user1
        await token.transfer(user1, 10);
        let balance = await token.balanceOf(user1);
        assert.equal(balance, 10);

        // Recipient tries to burn 11 tokens when balance is only 10
        await util.assertRevert(token.burn(11, { from: user1 }));
    });

});
