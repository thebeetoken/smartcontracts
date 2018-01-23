const BeePayments = artifacts.require("./BeePayments.sol");
const BeeToken = artifacts.require("./BeeToken.sol");
const util = require("./util.js");

contract('BeePayments Dispatch Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    const owner = accounts[0];
    const user1 = accounts[1];
    const demand = accounts[2];
    const supply = accounts[3];
    const uuid = "x";
    const aFee = 10;

    let token = null;
    let payments = null;

    beforeEach(async function () {
        payments = await BeePayments.new(user1, aFee, { from: owner});
        token = await BeeToken.new(user1, { from: owner});
    });

    async function initPayment(paymentId, time) {
        var cost = 50;
        var deposit = 20;
        var fee = 10;
        await payments.initPayment(paymentId, token.address, demand, supply, cost, deposit, fee, fee, 300, 1800, { from: owner });
    }

    async function sendTransaction(value, user) {
        await payments.sendTransaction({ value: util.toEther(value), from: user });
    }

    it("should enable transfers", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);
    });

    it("should initialize payment", async function () {
        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);
    });

    it("should not initialize existing payment", async function () {
        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);
        await util.expectThrow(initPayment(uuid, 0));
    });

    it("should revert when sending ether", async function () {
        await util.assertRevert(sendTransaction(1, user1));
    });

    it("should update arbiter address", async function () {
        await payments.updateArbitrationAddress(user1, { from: owner });
    });

    it("should update arbitration fee", async function () {
        await payments.updateArbitrationFee(10, { from: owner });
    });

    it("should not let non-owners update arbitration address", async function () {
        await util.assertRevert(payments.updateArbitrationAddress(user1, { from: supply}))
    });

    it("should not let non-owners update arbitration fee", async function () {
        await util.assertRevert(payments.updateArbitrationFee(10, { from: supply}))
    });

    it("should not let outside parties pay", async function () {
        await util.assertRevert(payments.pay(uuid, { from: user1 }));
    });

    it("should allow demand and supply entities pay", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
    });

    it("should not allow cancellation from outsiders", async function () {
        await util.assertRevert(payments.cancelPayment(uuid, { from: owner }));
    });

    it("should not allow outsider to dispute", async function () {
        await util.assertRevert(payments.disputePayment(uuid, { from: user1 }));
    });

    // need to adjust time to dispatch evm.time_increase
    it("should dispatch a specific payment", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");

        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await payments.dispatchPayment(uuid, { from: owner });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 950);
        assert.equal(s, 1050);
    });

    it("should dispatch payment list", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");

        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await payments.dispatchPayments([uuid], { from: owner });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 950);
        assert.equal(s, 1050);
    });

    it("should allow cancellation from demand without fee", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        await payments.cancelPayment(uuid, { from: demand });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 1000);
        assert.equal(s, 1000);
    });
    
    it("should allow cancellation from supply without fee", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        await payments.cancelPayment(uuid, { from: supply });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 1000);
        assert.equal(s, 1000);
    });

});

contract('BeePayments Cancel Test', function (accounts) {
    const owner = accounts[0];
    const user1 = accounts[1];
    const demand = accounts[2];
    const supply = accounts[3];
    const uuid = "x";
    const aFee = 10;

    let token = null;
    let payments = null;

    beforeEach(async function () {
        payments = await BeePayments.new(user1, aFee, { from: owner});
        token = await BeeToken.new(user1, { from: owner});
    });

    async function initPayment(paymentId, time) {
        var cost = 50;
        var deposit = 20;
        var fee = 10;
        await payments.initPayment(paymentId, token.address, demand, supply, cost, deposit, fee, fee, (time + 10), (time + 50), { from: owner });

    }
    async function sendTransaction(value, user) {
        await payments.sendTransaction({ value: util.toEther(value), from: user });
    }

    it("should not dispatch before ready", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        await util.assertRevert(payments.dispatchPayment(uuid, { from: owner }));
    });

    it("should not allow cancellation from outsiders", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        await util.assertRevert(payments.cancelPayment(uuid, { from: owner }));
    });

    it("should allow cancellation from demand", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        await payments.cancelPayment(uuid, { from: demand });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 990);
        assert.equal(s, 1010);
    });

    it("should allow cancellation from supply", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        await payments.cancelPayment(uuid, { from: supply });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 1010);
        assert.equal(s, 990);
    });
});

contract('BeePayments Arbitration Host Test', function (accounts) {
    const owner = accounts[0];
    const user1 = accounts[1];
    const demand = accounts[2];
    const supply = accounts[3];
    const arbiterAddress = accounts[4];
    const uuid = "x";
    const aFee = 10;

    let token = null;
    let payments = null;

    beforeEach(async function () {
        payments = await BeePayments.new(arbiterAddress, aFee, { from: owner});
        token = await BeeToken.new(user1, { from: owner});
    });

    async function initPayment(paymentId) {
        var cost = 50;
        var deposit = 20;
        var fee = 10;
        await payments.initPayment(paymentId, token.address, demand, supply, cost, deposit, fee, fee, 300, 1800, { from: owner });
    }
    async function sendTransaction(value, user) {
        await payments.sendTransaction({ value: util.toEther(value), from: user });
    }

    it("should allow host to raise disputes", async function () {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        var arb = await payments.arbitrationAddress();
        var contractBalance = (await token.balanceOf(payments.address)).toNumber();
        console.log(contractBalance);
        var fee = (await payments.arbitrationFee()).toNumber();
        await token.approve(arb, fee, { from: supply });
        var allowanceS = (await token.allowance(supply, arb)).toNumber();
        console.log(allowanceS);
        await payments.disputePayment(uuid, {from : supply});
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        console.log(d,s);
        assert.equal(d, 920);
        assert.equal(s, 980);
    });
            
    it("should allow guest to raise disputes", async function() {
        await token.enableTransfer();
        let isEnabled = await token.transferEnabled();
        assert(isEnabled, "transfers should be enabled");
        await token.transfer(demand, 1000, { from: owner });
        await token.transfer(supply, 1000, { from: owner });
        let demandBalance = (await token.balanceOf(demand)).toNumber();
        let supplyBalance = (await token.balanceOf(supply)).toNumber();
        assert.equal(demandBalance, 1000);
        assert.equal(supplyBalance, 1000);

        await initPayment(uuid);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);

        var payStruct = await payments.allPayments(uuid);
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await token.approve(payments.address, 500, { from: demand });
        await token.approve(payments.address, 500, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "2");
        var arb = await payments.arbitrationAddress();
        var fee = (await payments.arbitrationFee()).toNumber();
        assert.equal(fee, aFee);
        assert.equal(arb, arbiterAddress);
        await token.approve(arbiterAddress, fee, { from: demand });
        var allowanceD = (await token.allowance(demand, arbiterAddress)).toNumber();
        var allowance = (await token.allowance(demand, payments.address)).toNumber();
        await payments.disputePayment(uuid, {from: demand});
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 910);
        assert.equal(s, 990);
        var arbBalance = (await token.balanceOf(arb)).toNumber();
        assert.equal(arbBalance, 100);
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        assert.equal(status, "3");
    });
});
