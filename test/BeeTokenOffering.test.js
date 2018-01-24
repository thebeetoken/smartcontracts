
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeeToken = artifacts.require("./BeeToken.sol");
var util = require("./util.js");

contract('Whitelist Crowdsale', function (accounts) {
    var owner = accounts[0];
    var admin = accounts[1];
    var user2 = accounts[2];
    var user3 = accounts[3];
    var user4 = accounts[4];
    var user5 = accounts[5];
    var user6 = accounts[6];
    var beneficiary = accounts[7];

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

    async function sendTransaction(value, user) {
        await offering.sendTransaction({ value: util.toEther(value), from: user });
    }

    async function balanceOf(user) {
        return (await token.balanceOf(user)).toNumber();
    }

    it("should sell tokens at a prespecified rate", async function () {
        // user in tier 0, so cap is 3x of the base cap, 3 ethers
        await offering.whitelist(0, [user2], { from: owner });

        // 1 ETH is well below the cap
        const contribution1 = 1;
        await sendTransaction(contribution1, user2);
        assert.equal(await balanceOf(user2), util.toEther(await offering.rate()));
        assert.equal((await offering.weiRaised()).toNumber(), util.toEther(contribution1));

        // Sending more ETH to reach the cap
        const contribution2 = 2;
        const sum = contribution1 + contribution2;
        await sendTransaction(contribution2, user2);
        assert.equal(await balanceOf(user2), util.toEther(sum * (await offering.rate())));
        assert.equal((await offering.weiRaised()).toNumber(), util.toEther(sum));
    });

    it("should disallow unregistered users to buy tokens", async function () {
        await util.assertRevert(sendTransaction(1, user2));
    });

    it("should reject transactions with 0 value", async function () {
        await offering.whitelist(0, [user2], { from: owner });
        await util.assertRevert(sendTransaction(0, user2));
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