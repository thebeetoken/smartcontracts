var BeeTokenOffering = artifacts.require("./BeeTokenOffering.sol");
var BeeToken = artifacts.require("./BeeToken.sol");

var util = require("../util.js");
var bigInt = require("big-integer");

contract('Whitelist Crowdsale', function(accounts) {

    var owner = accounts[0];
    var beneficiary = accounts[1];
    var user2 = accounts[2];
    var user3 = accounts[3];
    var user4 = accounts[4];
    var user5 = accounts[5];
    var user6 = accounts[6];

    beforeEach(function() {
    return BeeTokenOffering.deployed().then(function(instance) {
        sale = instance;
        return BeeToken.deployed();
    }).then(function(instance2){
      token = instance2;
      return token.INITIAL_SUPPLY();
    }).then(function(val){
      initialSupply = val.toNumber();
      return token.owner();
    }).then(function(owner){
      tokenOwner = owner;
      return token.TOKEN_OFFERING_ALLOWANCE();
    }).then(function(val){
      crowdsaleSupply = val.toNumber();
    });
    });

    it("should add user2 to the whitelist", async function() {
        // 0 indicates all crowdsale tokens
        var address2 = [user2];
        
        await token.setTokenOffering(sale.address, 0); // ensures crowdsale has allowance of tokens
        await sale.startOffering(300);

        await sale.whitelistTierA(address2, {from:owner});
        
        var r = await sale.whitelistA(user2)

        assert.equal(r, true, "whitelistA is wrong");

    });

    it("should allow multiple users to be added to the whitelistA", async function() {
        var addresses = [user4, user5, user6];

        await sale.whitelistTierA(addresses, {from:owner});

        await sale.sendTransaction({from: user4,  value: util.oneEther});
        await sale.sendTransaction({from: user5,  value: util.oneEther});
        await sale.sendTransaction({from: user6,  value: util.twoEther});

        let saleBalance4 = (await sale.contributions(user4)).toNumber();
        let saleBalance5 = (await sale.contributions(user5)).toNumber();
        let saleBalance6 = (await sale.contributions(user6)).toNumber();

        assert.equal(saleBalance4, util.oneEther, "User4 sale balance is wrong");
        assert.equal(saleBalance5, util.oneEther, "User5 sale balance is wrong");
        assert.equal(saleBalance6, util.twoEther, "User6 sale balance is wrong");


    });
        it("should add user2 to the whitelist", async function() {
        var address2 = [user2];

        await sale.whitelistTierB(address2, {from:owner});
        
        var r = await sale.whitelistB(user2)

        assert.equal(r, true, "whitelistB is wrong");

    });

    it("should allow multiple users to be added to the whitelistB", async function() {
        var addresses = [user4, user5, user6];

        await sale.whitelistTierB(addresses, {from:owner});

        await sale.sendTransaction({from: user4,  value: util.oneEther});
        await sale.sendTransaction({from: user5,  value: util.oneEther});
        await sale.sendTransaction({from: user6,  value: util.twoEther});

        let saleBalance4 = (await sale.contributions(user4)).toNumber();
        let saleBalance5 = (await sale.contributions(user5)).toNumber();
        let saleBalance6 = (await sale.contributions(user6)).toNumber();

        assert.equal(saleBalance4, util.twoEther, "User4 sale balance is wrong");
        assert.equal(saleBalance5, util.twoEther, "User5 sale balance is wrong");
        assert.equal(saleBalance6, util.fourEther, "User6 sale balance is wrong");


    });
        it("should add user2 to the whitelist", async function() {
        var address2 = [user2];

        await sale.whitelistTierC(address2, {from:owner});
        
        var r = await sale.whitelistC(user2)

        assert.equal(r, true, "whitelistC is wrong");

    });

    it("should allow multiple users to be added to the whitelistC", async function() {
        var addresses = [user4, user5, user6];

        await sale.whitelistTierC(addresses, {from:owner});

        await sale.sendTransaction({from: user4,  value: util.oneEther});
        await sale.sendTransaction({from: user5,  value: util.oneEther});
        await sale.sendTransaction({from: user6,  value: util.twoEther});

        let saleBalance4 = (await sale.contributions(user4)).toNumber();
        let saleBalance5 = (await sale.contributions(user5)).toNumber();
        let saleBalance6 = (await sale.contributions(user6)).toNumber();

        assert.equal(saleBalance4, util.threeEther, "User4 sale balance is wrong");
        assert.equal(saleBalance5, util.threeEther, "User5 sale balance is wrong");
        assert.equal(saleBalance6, util.sixEther, "User6 sale balance is wrong");


    });
        it("should add user2 to the whitelist", async function() {
        var address2 = [user2];
            
        await sale.whitelistTierD(address2, {from:owner});
        
        var r = await sale.whitelistA(user2)

        assert.equal(r, true, "whitelistD is wrong");

    });

    it("should allow multiple users to be added to the whitelistD", async function() {
        var addresses = [user4, user5, user6];

        await sale.whitelistTierD(addresses, {from:owner});

        await sale.sendTransaction({from: user4,  value: util.oneEther});
        await sale.sendTransaction({from: user5,  value: util.oneEther});
        await sale.sendTransaction({from: user6,  value: util.twoEther});

        let saleBalance4 = (await sale.contributions(user4)).toNumber();
        let saleBalance5 = (await sale.contributions(user5)).toNumber();
        let saleBalance6 = (await sale.contributions(user6)).toNumber();

        assert.equal(saleBalance4, util.fourEther, "User4 sale balance is wrong");
        assert.equal(saleBalance5, util.fourEther, "User5 sale balance is wrong");
        assert.equal(saleBalance6, util.sixEther, "User6 sale balance is wrong");


    });
});