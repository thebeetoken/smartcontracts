
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeeTokenToken = artifacts.require("./BeeToken.sol");
var util = require("./util.js");

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
        BeeTokenoffering = instance;
        return BeeTokenToken.deployed();
    }).then(function(instance2){
      token = instance2;
      return token.INITIAL_SUPPLY();
    });
  });

  async function whitelistTierA (user) {
      await BeeTokenOffering.whitelistTierA(user, {from : owner});
  }

  async function sendTransaction (value, user) {
      await BeeTokenOffering.sendTransaction({value : util.toEther(value), from : user});
  }

  async function balanceOf (user) {
      return (await token.balanceOf(user)).toNumber();
  }

  it("should not allow to contribute more than allowed by the cap", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await whitelistTierA(user3);
      if ((await BeeTokenOffering.currentTime()) <= (await BeeTokenOffering.capTime())) {
        await util.expectThrow(sendTransaction(16, user3));
      }
  });

  it("should sell tokens at a prespecified rate", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await whitelistTierA(user2);

      // 1 ETH is well below the cap
      const contribution1 = 1;
      await sendTransaction(contribution1, user2);
      assert.equal(await balanceOf(user2), util.toBee(await BeeTokenOffering.rate()));
      assert.equal((await BeeTokenOffering.weiRaised()).toNumber(), util.toEther(contribution1));

      // Sending more ETH to reach the cap
      const contribution2 = 4;
      const sum = contribution1 + contribution2;
      await sendTransaction(contribution2, user2);
      assert.equal(await balanceOf(user2), util.toBee(sum * (await BeeTokenOffering.rate())));
      assert.equal((await BeeTokenOffering.weiRaised()).toNumber(), util.toEther(sum));
  });



  it("should not allow to contribute less than the min allowed amount of ETH", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await BeeTokenOffering.whitelistTierA(user3, {from:owner});
      const minimumContributionInWei = (await BeeTokenOffering.minContribution()).toNumber();
      if (minimumContributionInWei > 0) {
          await util.expectThrow(sendTransaction(minimumContributionInWei - 1, user3));
      }
  });

  it("should disallow unregistered users to buy tokens", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await util.expectThrow(sendTransaction(1, user5));
  });

  it("should reject transactions with 0 value", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await util.expectThrow(sendTransaction(0, user5));
  });

  it("should reject the address 0", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await util.expectThrow(BeeTokenOffering.whitelistTierA(0, {from:owner}));
  });

  it("should deactivate only registered addresses", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await util.expectThrow(BeeTokenOffering.deactivate(accounts[6]));
  });

  it("should keep the balance constant before and after reactivation", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await BeeTokenOffering.whitelistTierA(user2);
      await BeeTokenOffering.sendTransaction({value: util.twoEther, from:user2});

      const balance = await balanceOf(user2);
      await BeeTokenOffering.deactivate(user2);
      await BeeTokenOffering.whitelistTierA(user2);
      const balanceAfterReactivation = await balanceOf(user2);
      assert.equal(balance, balanceAfterReactivation);
  });

  it("should disallow sending too much gas during the initial cap period", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await whitelistTierA(accounts[8]);
      if ((await BeeTokenOffering.currentTime()) <= (await BeeTokenOffering.capTime())) {
        const tooMuchGas = 1 + (await BeeTokenOffering.GAS_LIMIT_IN_WEI()).toNumber();
        let isCorrect = false;
        try {
          await BeeTokenOffering.sendTransaction({value : util.oneEther, from : accounts[8], gas: tooMuchGas});
        }
        catch (error) {
          isCorrect = error.message.search('Exceeds block gas limit') >= 0;
        }
        assert.equal(isCorrect, true);
      }
  });

  it("should allow sending gas that fall within range during cap period", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await whitelistTierA(accounts[8]);
      if ((await BeeTokenOffering.currentTime()) <= (await BeeTokenOffering.capTime())) {
        const adequetGas = (await BeeTokenOffering.GAS_LIMIT_IN_WEI()).toNumber(); //50000000000
        console.log('typeof adequetGas:',typeof adequetGas);
        //let r = await BeeTokenOffering.test({gas:30000000000, value:50000, from:accounts[8]});
        let isCorrect = false;
        try {
          await BeeTokenOffering.sendTransaction({value : util.twoEther, from : accounts[8], gasprice: 30000000000});

          /* All these variations throw an error which gets caught */
          // await BeeTokenOffering.sendTransaction({value : util.twoEther, from : accounts[8], gas: 20000000});
          // await BeeTokenOffering.sendTransaction({value : util.twoEther, from : accounts[8], gas: adequetGas});
          // await BeeTokenOffering.sendTransaction({value : util.twoEther, from : accounts[8], gas: 5000000});
        }
        catch (error) {
          console.log('error:',error);
          isCorrect = error.message.search('Exceeds block gas limit') >= 0;
        }
        assert.equal(isCorrect, false);
      }
  });

  it("should reach the cap", async function() {
      await token.setTokenOffering(BeeTokenOffering.address, 0);
      await BeeTokenOffering.whitelistTierA(user5, {from:owner});
      await sendTransaction(13, user5);
      assert.equal(await BeeTokenOffering.fundingCapReached(), true);
  });
});
