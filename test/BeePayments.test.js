var BeePayments = artifacts.require("./BeePayments.sol");
var BeeToken = artifacts.require("./BeeToken.sol");
var util = require("./util.js");
var bigInt = require("big-integer");

    contract('BeePayments Test', function(accounts) {
        // account[0] points to the owner on the testRPC setup
        var owner = accounts[0];
        var user1 = accounts[1];
        var demand = accounts[2];
        var supply = accounts[3];
        var uuid = "2D711642B726B04401627CA9FBAC32F5C8530FB1903CC4DB02258717921A4881";


        beforeEach(function() {
            return BeePayments.deployed().then(function(instance) {
                payments = instance;
                return BeeToken.deployed();
            }).then(function(instance2){
                token = instance2;
                return token.INITIAL_SUPPLY();
            });
        });

        async function initPayment (paymentId, user) {
            var cost = bigInt("5e18");
            var deposit = bigInt("2e18");
            var fee = bigInt("1e18");
            await payments.initPayment(paymentId, token.address, demand, supply, cost, deposit, fee, fee, 300, 1800, {from : user});
        }
        async function sendTransaction (value, user) {
            await payments.sendTransaction({value : util.toEther(value), from : user});
        }

        it("should enable transfers", async function() {
            await token.enableTransfer();
            let isEnabled = await token.transferEnabled();
            assert(isEnabled, "transfers should be enabled");
            await token.transfer(demand, 1000, {from: owner});
            await token.transfer(supply, 1000, {from: owner});
            let demandBalance = (await token.balanceOf(demand)).toNumber();
            let supplyBalance = (await token.balanceOf(supply)).toNumber();
            assert.equal(demandBalance, 1000);
        });

        it("should initialize payment", async function() {
            await initPayment(uuid, owner);
            assert(payments.allPayments[uuid].exist);
        });

        it("should allow demand and supply entity pay", async function() {
            await payments.pay(uuid, {from : demand});
            await payments.pay(uuid, {from : supply});

            assert.equal(payments.allPayments[uuid].paymentStatus, PaymentStatus.IN_PROGRESS);
        });
        
        it("should revert when sending ether", async function() {
            await util.expectThrow(sendTransaction(1 , user1));
        });
        
        it("should update arbiter address", async function() {
            await payments.updateArbitrationAddress(user1, {from : owner});
        });
        
        it("should allow guest or host to pay", async function() {
            await payments.pay(uuid, {from : demand});
            await payments.pay(uuid, {from : supply});
            
        });
        
        it("should revert if not guest or host", async function() {
            await util.expectThrow(payments.pay(uuid, {from : user1}));
        });
        
        it("should not dispatch payment before ready", async function() {
            await util.expectThrow(payments.dispatchPayment(uuid, {from : owner}));
        });
        
        // need to adjust time to dispatch
        it("should dispatch a specific payment", async function() {
            await payments.dispatchPayment(uuid, {from : owner});
        });
        
        it("should not allow cancellation from outsiders", async function() {
            await util.expectThrow(payments.cancelPayment(uuid, {from : owner}));
        });
        
        it("should allow cancellation from demand", async function() {
            await payments.cancelPayment(uuid, {from : demand});
        });
        
        it("should allow cancellation from supply", async function() {
            await payments.cancelPayment(uuid, {from : supply});
        });
        
        it("should not allow outsider to dispute", async function() {
            await util.expectThrow(payments.disputePayment(uuid, 0, {from : user1}));
        });
        
        it("should allow guest to raise disputes", async function() {
            await payments.disputePayment(uuid, 0, {from : demand});
        });
        
        it("should allow host to raise disputes", async function() {
            await payments.disputePayment(uuid, 0, {from : supply});
        });
        
        
        
        
           
        
/*        ** need to call approve from the token contract
Constructor(BeePayments) (checked ~ good)
Fallback ~ expect revert (checked ~ good)
Update arbitration address ~ possible vulnerability if owner is hijacked (checked ~ good)
initPayment ~ same as above (checked ~ truffle bug requires workaround. Anything associated with this initing payment will throw)
Pay ~ works mostly. Make sure to call web3** (checked ~ requires init)
dispatchPayment ~ make sure transfer works (unchecked ~ requires init)
*s ~ check gas costs. Need to call init and pay a lot to have any effect (unchecked ~ requires init)
cancelPayment ~ need time machine to check cancellation fees. 4 different test (unchecked ~ requires init)
disputePayment ~ check if funds are sent to arbitration address. Make sure to call web3** (unchecked ~ requires init)
*/


    });
