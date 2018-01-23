
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeeToken = artifacts.require("./BeeToken.sol");
var util = require("./util.js");
var bigInt = require("big-integer");

contract('BeeTokenOffering constructor', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0];
    var admin = accounts[1];
    var beneficiary = accounts[6];
    var user2 = accounts[2];
    var user3 = accounts[3];
    var user4 = accounts[4];
    var user5 = accounts[5];

    var token = null;
    var offering = null;
    beforeEach(async function () {
        token = await BeeToken.new(admin, { from: owner });
        offering = await BeeTokenOffering.new(
            5000, beneficiary, 10, token.address, { from: owner }
        );
    });

    async function whitelistTierA(user) {
        await offering.whitelist(0, [user], { from: owner });
    }

    async function sendTransaction(value, user) {
        await offering.sendTransaction({ value: util.toEther(value), from: user });
    }

    async function balanceOf(user) {
        return (await token.balanceOf(user)).toNumber();
    }
    /*
      it("should not allow to contribute more than allowed by the cap", async function() {
          await token.setTokenOffering(offering.address, 0);
          await offering.startOffering(300);
          await whitelistTierA(user3);
          if ((await offering.currentTime()) <= (await offering.doubleTime())) {
            await util.assertRevert(sendTransaction(16, user3));
          }
      });
    */
    it("should sell tokens at a prespecified rate", async function () {
        await token.setTokenOffering(offering.address, 0);
        await offering.startOffering(300);
        await whitelistTierA(user2);

        // 1 ETH is well below the cap
        const contribution1 = 1;
        await sendTransaction(contribution1, user2);
        assert.equal(await balanceOf(user2), util.toEther(await offering.rate()));
        assert.equal((await offering.weiRaised()).toNumber(), util.toEther(contribution1));

        // Sending more ETH to reach the cap
        const contribution2 = 4;
        const sum = contribution1 + contribution2;
        await sendTransaction(contribution2, user2);
        assert.equal(await balanceOf(user2), util.toEther(sum * (await offering.rate())));
        assert.equal((await offering.weiRaised()).toNumber(), util.toEther(sum));
    });

    it("should disallow unregistered users to buy tokens", async function () {
        await token.setTokenOffering(offering.address, 0);
        await util.assertRevert(sendTransaction(1, user5));
    });

    it("should reject transactions with 0 value", async function () {
        await token.setTokenOffering(offering.address, 0);
        await util.assertRevert(sendTransaction(0, user5));
    });
    /*
      it("should reach the cap", async function() {
          //await token.setTokenOffering(offering.address, 0);
          //await offering.startOffering(300);
          await offering.whitelistTierA([user5], {from:owner});
          await sendTransaction(13, user5);
          assert.equal(await offering.fundingCapReached(), true);
      });
    */
    it("should not allow non-owners to call ownerSafeWithdraw", async function () {
        await token.setTokenOffering(offering.address, 0);
        await util.assertRevert(offering.allocateTokensBeforeOffering(user3, util.oneEther, util.twoEther, { from: user2 }));
    });
    /*    
      it("should allow transfers to registered users, even beyond caps", async function(){
        await whitelistTierA(user2);
        await whitelistTierA(user3);
    
        await offering.allocateTokens(user2, util.oneEther, util.oneEther, {from:owner});
    
        await offering.allocateTokens(user3, util.twoEther, util.oneEther, {from:owner});
        let addrList = [user2, user3];
        let amtsList = [util.oneEther, util.twoEther];
        let user2_balance = await(offering.contributions(user2));
        let user2_token_balance = await(token.balanceOf(user2));
        await offering.allocateTokens(user2, util.oneEther, util.oneEther, {from:owner});
        await offering.allocateTokens(user3, util.twoEther, util.twoEther, {from:owner});
    
    
        let reached_cap = await offering.fundingCapReached();
        let user2_balance_after = await(offering.contributions(user2));
        let user2_token_balance_after = await(token.balanceOf(user2));
        console.log(user2_balance.add(util.oneEther) + " " + user2_balance_after + " " + reached_cap);
        assert.equal(user2_balance.add(util.oneEther).toNumber(), user2_balance_after.toNumber(), "user2 ether balance should have increased by 1");
        assert.equal(user2_token_balance.add(util.oneEther).toNumber(), user2_token_balance_after.toNumber(), "user2 token balance should have increased by 1");
    
      });
    */

    it("should allow transfers to unregistered users", async function () {
        await token.setTokenOffering(offering.address, 0);
        await offering.allocateTokensBeforeOffering(user4, util.oneEther, util.oneEther, { from: owner });
    });

});


contract('Whitelist Crowdsale', function (accounts) {
    var owner = accounts[0];
    var admin = accounts[1];
    var beneficiary = accounts[7];
    var user2 = accounts[2];
    var user3 = accounts[3];
    var user4 = accounts[4];
    var user5 = accounts[5];
    var user6 = accounts[6];

    var token = null;
    var offering = null;
    beforeEach(async function () {
        token = await BeeToken.new(admin, { from: owner });
        offering = await BeeTokenOffering.new(
            5000, beneficiary, 1 /*base cap*/, token.address, { from: owner }
        );

        // automatically start offering
        await token.setTokenOffering(offering.address, 0);
        await offering.startOffering(300);
    });

    it("Check if people are added correctly in whitelists", async function () {
        await offering.whitelist(0, [user2], { from: owner });
        var r = await offering.whitelists(0, user2)
        assert.equal(r, true, "whitelist0 works");

        await offering.whitelist(1, [user3], { from: owner });
        r = await offering.whitelists(1, user3)
        assert.equal(r, true, "whitelist1 works");

        await offering.whitelist(2, [user4], { from: owner });
        r = await offering.whitelists(2, user4)
        assert.equal(r, true, "whitelist2 works");
    });

    it("not whitelisted address should fail sending ether", async function () {
        // should fail even send ether within the base cap
        await util.assertRevert(offering.sendTransaction({ from: user4, value: util.oneEther }));
    });

    it("whitelist addresses in whitelist0 -- 3x base cap, 3 ethers", async function () {
        var addresses = [user4, user5, user6];

        await offering.whitelist(0, addresses, { from: owner });

        await offering.sendTransaction({ from: user4, value: util.twoEther });
        await offering.sendTransaction({ from: user5, value: util.threeEther });
        // fails when more than cap
        await util.assertRevert(offering.sendTransaction({ from: user6, value: util.fourEther }));

        let saleBalance4 = (await offering.contributions(user4)).toNumber();
        let saleBalance5 = (await offering.contributions(user5)).toNumber();

        assert.equal(saleBalance4, util.twoEther, "should pass when less than cap");
        assert.equal(saleBalance5, util.threeEther, "should pass when equal cap");
    });

    it("whitelist addresses in whitelist1 -- 2x base cap, 2 ethers", async function () {
        var addresses = [user4, user5, user6];

        await offering.whitelist(1, addresses, { from: owner });

        await offering.sendTransaction({ from: user4, value: util.oneEther });
        await offering.sendTransaction({ from: user5, value: util.twoEther });
        await util.assertRevert(offering.sendTransaction({ from: user6, value: util.threeEther }));

        let saleBalance4 = (await offering.contributions(user4)).toNumber();
        let saleBalance5 = (await offering.contributions(user5)).toNumber();

        assert.equal(saleBalance4, util.oneEther, "should pass when less than cap");
        assert.equal(saleBalance5, util.twoEther, "should pass when equal cap");
    });

    it("whitelist addresses in whitelist2 -- 1x base cap, 1 ether", async function () {
        var addresses = [user4, user5, user6];

        await offering.whitelist(2, addresses, { from: owner });

        await offering.sendTransaction({ from: user4, value: util.halfEther });
        await offering.sendTransaction({ from: user5, value: util.oneEther });
        await util.assertRevert(offering.sendTransaction({ from: user6, value: util.twoEther }));

        let saleBalance4 = (await offering.contributions(user4)).toNumber();
        let saleBalance5 = (await offering.contributions(user5)).toNumber();

        assert.equal(saleBalance4, util.halfEther, "should pass when less than cap");
        assert.equal(saleBalance5, util.oneEther, "should pass when equal cap");
    });
});