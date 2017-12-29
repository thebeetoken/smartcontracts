
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeeToken = artifacts.require("./BeeToken.sol");
var util = require("./util.js");
var bigInt = require("big-integer");

contract('BeeTokenOffering constructor', function(accounts) {
  // account[0] points to the owner on the testRPC setup
  var owner = accounts[0];
  var user1 = accounts[1];
  var user2 = accounts[2];
  var user3 = accounts[3];
  var user4 = accounts[4];
  var user5 = accounts[5];

  beforeEach(function() {
    return BeeTokenOffering.deployed().then(function(instance) {
        offering = instance;
        return BeeToken.deployed();
    }).then(function(instance2){
      token = instance2;
      return token.INITIAL_SUPPLY();
    });
  });

  async function whitelistTierA (user) {
      await offering.whitelistTierA([user], {from : owner});
  }

  async function sendTransaction (value, user) {
      await offering.sendTransaction({value : util.toEther(value), from : user});
  }

  async function balanceOf (user) {
      return (await token.balanceOf(user)).toNumber();
  }
/*
  it("should not allow to contribute more than allowed by the cap", async function() {
      await token.setTokenOffering(offering.address, 0);
      await offering.startOffering(300);
      await whitelistTierA(user3);
      if ((await offering.currentTime()) <= (await offering.doubleTime())) {
        await util.expectThrow(sendTransaction(16, user3));
      }
  });
*/
  it("should sell tokens at a prespecified rate", async function() {
      await token.setTokenOffering(offering.address, 0);
      await offering.startOffering(300);
      await whitelistTierA(user2);

      // 1 ETH is well below the cap
      const contribution1 = 1;
      await sendTransaction(contribution1, user2);
      //assert.equal(await balanceOf(user2), util.toEther(await offering.rate()));
      assert.equal((await offering.weiRaised()).toNumber(), util.toEther(contribution1));

      // Sending more ETH to reach the cap
      const contribution2 = 4;
      const sum = contribution1 + contribution2;
      await sendTransaction(contribution2, user2);
      //assert.equal(await balanceOf(user2), util.toEther(sum * (await offering.rate())));
      assert.equal((await offering.weiRaised()).toNumber(), util.toEther(sum));
  });

  it("should disallow unregistered users to buy tokens", async function() {
      //await token.setTokenOffering(offering.address, 0);
      await util.expectThrow(sendTransaction(1, user5));
  });

  it("should reject transactions with 0 value", async function() {
      //await token.setTokenOffering(offering.address, 0);
      await util.expectThrow(sendTransaction(0, user5));
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
  it("should not allow non-owners to call ownerSafeWithdraw", async function() {
    await token.setTokenOffering(offering.address, 0);
    await util.expectThrow(offering.allocateTokens(user3, util.oneEther, util.twoEther, {from:user2}));
    await util.expectThrow(offering.allocateTokens(user3, util.oneEther, util.twoEther, {from:user1}));
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

  it("should allow transfers to unregistered users", async function(){
    await offering.allocateTokens(user4, util.oneEther, util.oneEther, {from:owner});
  });
  
});
