
var BeeToken = artifacts.require("./BeeToken.sol");
var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var bigInt = require("big-integer");


const timeTravel = function (time) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync({
      jsonrpc: "2.0",
      method: "evm_increaseTime",
      params: [time], // 86400 is num seconds in day
      id: new Date().getTime()
    }, (err, result) => {
      if(err){ return reject(err) }
      return resolve(result)
    });
  })
}

contract('BeeToken (Basic Tests)', function(accounts) {
  // account[0] points to the owner on the testRPC setup
  var owner = accounts[0];
  var user1 = accounts[1];
  var user2 = accounts[2];
  var user3 = accounts[3];

  beforeEach(function() {
    return BeeTokenOffering.deployed().then(function(instance) {
        offering = instance;
        return BeeToken.deployed();
    }).then(function(instance2){
      token = instance2;
      return token.INITIAL_SUPPLY();
    });
  });

  it("should have 18 decimal places", async function() {
    var decimals = await token.DECIMALS();
    assert.equal(decimals, 18);
  });

  it("transferEnabled is initialized to false", async function() {
    var result = await token.transferEnabled();
    assert.equal(result, false);
  });

  it("should have an initial owner balance of 500 million tokens", async function() {
      let ownerBalance = (await token.balanceOf(owner)).toNumber();

      assert.equal(ownerBalance, bigInt("5e26"), "the owner balance should initially be 500 million tokens");
  });

  it("should not allow a regular user to transfer before they are enabled", async function() {
      try{
        await token.transfer(user2, 10, {from: user1});
      }
      catch (e){
        return true;
      }
      throw new Error("a regular user transferred before they were enabled")
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

  it("should not allow a regular user to enable transfers", async function() {
      let token = await BeeToken.deployed();
      try{
        await token.enableTransfer({from: user1});
      }
      catch (e){
        return true;
      }
      throw new Error("a regular user was able to call enableTransfer")
  });

  it("should enable transfers after invoking enableTransfer as owner", async function() {
      let isEnabledBefore = await token.transferEnabled();
      assert(!isEnabledBefore, "transfers should not be enabled");
      await token.enableTransfer();
      let isEnabledAfter = await token.transferEnabled();
      assert(isEnabledAfter, "transfers should be enabled");
  });

});

contract('BeeToken (token burning tests)', function(accounts) {

  // account[0] points to the owner on the testRPC setup
  var owner = accounts[0];
  var user1 = accounts[1];
  var user2 = accounts[2];
  var user3 = accounts[3];
  /*
  it("non-owner should not be able to burn tokens when transfers are not enabled", async function() {
    let token = await BeeToken.deployed();
    let transferEnabled = await token.transferEnabled();
    assert(!transferEnabled);

    // Owner transfers 10 tokens to user1
    await token.transfer(user1, 10);
    let balance = await token.balanceOf(user1);
    assert.equal(balance, 10);

    // Recipient tries to burn 3 tokens when transfers are not enabled
    try {
      await token.burn(3, {from: user1});
    }
    catch (e) {
      return true;
    }
    throw new Error("a regular user was able to burn tokens when transfers were not enabled")
  });
  */
});
