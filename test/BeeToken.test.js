
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
    const admin = accounts[3];

    let token = null;
    let offering = null;

    beforeEach(async function () {
        token = await BeeToken.new(admin, { from: owner });
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

    it("admin should have 350MM tokens in allowance", async function () {
        const adminAllowance = await token.allowance(owner, admin);
        assert.equal(adminAllowance, 3.5e26, "admin allowance should be right");
    })

    it("should allow owner to set token offering", async function () {
        assert.equal(await token.tokenOfferingAddr(), util.zeroAddress);
        await token.setTokenOffering(offering.address, 100);
        assert.equal(await token.tokenOfferingAddr(), offering.address);
    });

    it("should not allow non-owner to set token offering", async function () {
        assert.equal(await token.tokenOfferingAddr(), util.zeroAddress);
        // user1 is not owner of token
        await util.assertRevert(token.setTokenOffering(offering.address, 100, { from: user1 }));
    });

    it("Once transfer is Enabled, cannot setTokenOffering", async function () {
        let transferEnabled = await token.transferEnabled();
        assert.isFalse(transferEnabled);
        await token.enableTransfer({ from: owner });
        transferEnabled = await token.transferEnabled();
        assert.isTrue(transferEnabled);

        await util.assertRevert(token.setTokenOffering(offering.address, 100));
    });

    it("Token for sale cannot be greater than allowance", async function () {
        // offering allowance should be 1.5e26
        await util.assertRevert(token.setTokenOffering(offering.address, 2e26));
    });

    it("should not allow a regular user to enable transfers", async function () {
        await util.assertRevert(token.enableTransfer({ from: user1 }));
    });

    it("should not allow a regular user to transfer before they are enabled", async function () {
        await util.assertRevert(token.transfer(user1, 10, { from: user1 }));
    });

    it("should enable transfers after invoking enableTransfer as owner", async function () {
        let isEnabledBefore = await token.transferEnabled();
        assert.isFalse(isEnabledBefore, "transfers should not be enabled");
        await token.enableTransfer();
        let isEnabledAfter = await token.transferEnabled();
        assert.isTrue(isEnabledAfter, "transfers should be enabled");
    });

});

contract('BeeToken (transfers)', function (accounts) {
    const owner = accounts[0];
    const user1 = accounts[1];
    const user2 = accounts[2];
    const admin = accounts[3];
    const offeringAddress = accounts[4];

    let token = null;

    beforeEach(async function () {
        token = await BeeToken.new(admin, { from: owner });
    });

    it('Admin can transfers tokens before transfers are enabled, admin allowance should get updated properly', async function() {
        let adminAllowance = await token.allowance(owner, admin);
        assert.equal(adminAllowance, 3.5e26, 'original admin allowance');
        
        await token.transferFrom(owner, user1, 1000, { from: admin });
        
        adminAllowance = await token.allowance(owner, admin);
        assert.equal(adminAllowance, 3.5e26 - 1000, 'new admin allowance');

        const balance = await token.balanceOf(user1);
        assert.equal(balance, 1000);
    });

    it('Offering contract can transfers tokens before transfers are enabled, offering allowance should get updated properly', async function () {
        let offeringAllowance = await token.allowance(owner, offeringAddress);
        assert.equal(offeringAllowance, 0, 'original offering allowance');
        
        await token.setTokenOffering(offeringAddress, 1000);
        
        offeringAllowance = await token.allowance(owner, offeringAddress);
        assert.equal(offeringAllowance, 1000, 'new offering allowance');
        const offeringAddr = await token.tokenOfferingAddr();
        assert.equal(offeringAddr, offeringAddress);
        let totalOfferingAllowance = await token.tokenOfferingAllowance();
        assert.equal(totalOfferingAllowance, 1.5e+26, 'total offering allowance');


        let userBalance = await token.balanceOf(user1);
        assert.equal(userBalance, 0, 'original user balance');
        await token.transferFrom(owner, user1, 900, {from: offeringAddress});
        userBalance = await token.balanceOf(user1);
        assert.equal(userBalance, 900, 'new user balance');

        totalOfferingAllowance = await token.tokenOfferingAllowance();
        assert.equal(totalOfferingAllowance, 1.5e+26 - 999, 'new total offering allowance');
    });

    it('Transfer to invalid destination address', async function () {
        await token.transferFrom(owner, user1, 1000, { from: admin });
        
        await token.setTokenOffering(offeringAddress, 1000);
        
        await token.enableTransfer();
        const transferEnabled = await token.transferEnabled();
        assert.isTrue(transferEnabled);

        // fails: zero address
        await util.assertRevert(token.transfer(util.zeroAddress, 1000, { from: user1 }));
        // fails: to token contract
        await util.assertRevert(token.transfer(token.address, 1000, { from: user1 }));
        // fails: to owner
        await util.assertRevert(token.transfer(owner, 1000, { from: user1 }));
        // fails: to admin
        await util.assertRevert(token.transfer(admin, 1000, { from: user1 }));
        // fails: to offering address
        await util.assertRevert(token.transfer(offeringAddress, 1000, { from: user1 }));
    });

    it('A regular user calls transferFrom', async function () {
        const amount = 1000;
        await token.approve(user1, amount, { from: owner });
        const allowance = await token.allowance(owner, user1);
        assert.equal(allowance, amount, 'allowance should be updated');

        // enable transfer
        await token.enableTransfer();
        transferEnabled = await token.transferEnabled();
        assert.isTrue(transferEnabled, 'transfer enabled');

        // user2 is not the spender, expect this call to fail
        await util.assertRevert(token.transferFrom(owner, user2, 1000, { from: user2 }));

        // user1 transfer more than allowed
        await util.assertRevert(token.transferFrom(owner, user2, 1001, { from: user1 }));

        let user2Balance = await token.balanceOf(user2);
        assert.equal(user2Balance, 0, 'user2 balance 0');
        await token.transferFrom(owner, user2, 1000, { from: user1 });
        user2Balance = await token.balanceOf(user2);
        assert.equal(user2Balance, 1000, 'transfer to user2 succeeded');
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