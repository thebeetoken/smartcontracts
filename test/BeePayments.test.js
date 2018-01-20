var BeePayments = artifacts.require("./BeePayments.sol");
var BeeToken = artifacts.require("./BeeToken.sol");
var util = require("./util.js");

contract('BeePayments Dispatch Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0];
    var user1 = accounts[1];
    var demand = accounts[2];
    var supply = accounts[3];
    var uuid = "x";

    beforeEach(function () {
        return BeePayments.deployed().then(function (instance) {
            payments = instance;
            return BeeToken.deployed();
        }).then(function (instance2) {
            token = instance2;
            return token.INITIAL_SUPPLY();
        });
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
        await util.assertRevert(initPayment(uuid, 0));
    });

    it("should revert when sending ether", async function () {
        await util.assertRevert(sendTransaction(1, user1));
    });

    it("should update arbiter address", async function () {
        await payments.updateArbitrationAddress(user1, { from: owner });
    });

    it("should not let outside parties pay", async function () {
        await util.assertRevert(payments.pay(uuid, { from: user1 }));
    });

    it("should allow demand and supply entities pay", async function () {
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
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await payments.dispatchPayment(uuid, { from: owner });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 1050);
        assert.equal(s, 950);
    });

});

contract('BeePayments Guest Cancel Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0];
    var user1 = accounts[1];
    var demand = accounts[2];
    var supply = accounts[3];
    var uuid = "x";


    beforeEach(function () {
        return BeePayments.deployed().then(function (instance) {
            payments = instance;
            return BeeToken.deployed();
        }).then(function (instance2) {
            token = instance2;
            return token.INITIAL_SUPPLY();
        });
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
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);
    });

    it("should not let outside parties pay", async function () {
        await util.assertRevert(payments.pay(uuid, { from: user1 }));
    });

    it("should allow demand and supply entities pay", async function () {
        var payStruct = await payments.allPayments(uuid);
        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        var demandPaid = Boolean(payStruct[8]);
        var supplyPaid = Boolean(payStruct[9]);
        assert.equal(supplyPaid, true);
        assert.equal(demandPaid, true);
        assert.equal(status, "2");
    });

    it("should not dispatch before ready", async function () {
        await util.assertRevert(payments.dispatchPayment(uuid, { from: owner }));
    });

    it("should not allow cancellation from outsiders", async function () {
        await util.assertRevert(payments.cancelPayment(uuid, { from: owner }));
    });

    it("should allow cancellation from demand", async function () {
        await payments.cancelPayment(uuid, { from: demand });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 1080);
        assert.equal(s, 920);
    });
});
contract('BeePayments Host Cancel Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0];
    var user1 = accounts[1];
    var demand = accounts[2];
    var supply = accounts[3];
    var uuid = "x";


    beforeEach(function () {
        return BeePayments.deployed().then(function (instance) {
            payments = instance;
            return BeeToken.deployed();
        }).then(function (instance2) {
            token = instance2;
            return token.INITIAL_SUPPLY();
        });
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
        var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
        await initPayment(uuid, n);
        var payStruct = await payments.allPayments(uuid);
        var exist = payStruct[0];
        assert.equal(exist, true);
    });

    it("should not let outside parties pay", async function () {
        await util.assertRevert(payments.pay(uuid, { from: user1 }));
    });

    it("should allow demand and supply entities pay", async function () {
        var payStruct = await payments.allPayments(uuid);
        await token.approve(payments.address, 800, { from: demand });
        await token.approve(payments.address, 800, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);
        var demandPaid = Boolean(payStruct[8]);
        var supplyPaid = Boolean(payStruct[9]);
        assert.equal(supplyPaid, true);
        assert.equal(demandPaid, true);
        assert.equal(status, "2");
    });

    it("should not dispatch before ready", async function () {
        await util.assertRevert(payments.dispatchPayment(uuid, { from: owner }));
    });

    it("should not allow cancellation from outsiders", async function () {
        await util.assertRevert(payments.cancelPayment(uuid, { from: owner }));
    });

    it("should allow cancellation from supply", async function () {
        await payments.cancelPayment(uuid, { from: supply });
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        assert.equal(d, 1010);
        assert.equal(s, 990);
    });
});

contract('BeePayments Arbitration Host Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0];
    var user1 = accounts[1];
    var demand = accounts[2];
    var supply = accounts[3];
    var uuid = "x";


    beforeEach(function () {
        return BeePayments.deployed().then(function (instance) {
            payments = instance;
            return BeeToken.deployed();
        }).then(function (instance2) {
            token = instance2;
            return token.INITIAL_SUPPLY();
        });
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

    it("should not let outside parties pay", async function () {
        await util.assertRevert(payments.pay(uuid, { from: user1 }));
    });

    it("should allow demand and supply entities pay", async function () {
        var payStruct = await payments.allPayments(uuid);

        await token.approve(payments.address, 100, { from: demand });
        await token.approve(payments.address, 100, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);

        assert.equal(status, "2");
    });

    it("should allow host to raise disputes", async function () {
        var arb = await payments.arbitrationAddress();
        var contractBalance = (await token.balanceOf(payments.address)).toNumber();
        console.log(contractBalance);
        var fee = (await payments.arbitrationFee()).toNumber();
        await token.approve(arb, fee, { from: supply });
        var allowanceS = (await token.allowance(supply, arb));
        console.log(allowanceS);
        await payments.disputePayment(uuid, {from : supply});
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        console.log(d,s);
        //assert.equal(d, 990);
        //assert.equal(s, 920);
    });
});

contract('BeePayments Arbitration Guest Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0];
    var user1 = accounts[1];
    var demand = accounts[2];
    var supply = accounts[3];
    var uuid = "x";


    beforeEach(function () {
        return BeePayments.deployed().then(function (instance) {
            payments = instance;
            return BeeToken.deployed();
        }).then(function (instance2) {
            token = instance2;
            return token.INITIAL_SUPPLY();
        });
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

    it("should not let outside parties pay", async function () {
        await util.assertRevert(payments.pay(uuid, { from: user1 }));
    });

    it("should allow demand and supply entities pay", async function () {
        var payStruct = await payments.allPayments(uuid);

        await token.approve(payments.address, 100, { from: demand });
        await token.approve(payments.address, 100, { from: supply });
        await payments.pay(uuid, { from: demand });
        await payments.pay(uuid, { from: supply });
        var payStruct = await payments.allPayments(uuid);
        var status = payStruct[1].toString(10);

        assert.equal(status, "2");
    });
            
    it("should allow guest to raise disputes", async function() {
        var arb = await payments.arbitrationAddress();
        var fee = (await payments.arbitrationFee()).toNumber();
        console.log(fee);
        await token.approve(arb, fee, { from: demand });
        var allowanceD = (await token.allowance(demand, arb));
        var allowance = (await token.allowance(demand, payments.address));
        console.log(allowanceD,allowance);
        await payments.disputePayment(uuid, {from : demand});
        let d = (await token.balanceOf(demand)).toNumber();
        let s = (await token.balanceOf(supply)).toNumber();
        console.log(d,s)
    });
});
