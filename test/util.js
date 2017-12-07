var expectThrow = async function(promise) {
  try {
    await promise;
  } catch (error) {
    const invalidOpcode = error.message.search('invalid opcode') >= 0;
    const invalidJump = error.message.search('invalid JUMP') >= 0;
    const outOfGas = error.message.search('out of gas') >= 0;
    assert(
      invalidOpcode || invalidJump || outOfGas,
      "Expected throw, got '" + error + "' instead",
    );
    return;
  }
  assert.fail('Expected throw not received');
};

function toEther (n) {
    return web3.toWei(n, "ether");
}

module.exports = {

    expectThrow : async function(promise) {
        try {
            await
            promise;
        } catch (error) {
            const invalidOpcode = error.message.search('invalid opcode') >= 0;
            const invalidJump = error.message.search('invalid JUMP') >= 0;
            const outOfGas = error.message.search('out of gas') >= 0;
            assert(
                invalidOpcode || invalidJump || outOfGas,
                "Expected throw, got '" + error + "' instead",
            );
            return;
        }
        assert.fail('Expected throw not received');
    },

    logUserBalances : async function logUserBalances (token, accounts) {
        console.log("");
        console.log("User Balances:");
        console.log("--------------");
        console.log(`Owner: ${(await token.balanceOf(accounts[0])).toNumber()}`);
        console.log(`User1: ${(await token.balanceOf(accounts[1])).toNumber()}`);
        console.log(`User2: ${(await token.balanceOf(accounts[2])).toNumber()}`);
        console.log(`User3: ${(await token.balanceOf(accounts[3])).toNumber()}`);
        console.log(`User4: ${(await token.balanceOf(accounts[4])).toNumber()}`);

        console.log("--------------");
        console.log("");
    },

    logEthBalances : async function logEthBalances (token, offering, accounts) {
        console.log("");
        console.log("Eth Balances:");
        console.log("-------------");
        console.log(`Owner: ${(await web3.eth.getBalance(accounts[0])).toNumber()}`);
        console.log(`User1: ${(await web3.eth.getBalance(accounts[1])).toNumber()}`);
        console.log(`User2: ${(await web3.eth.getBalance(accounts[2])).toNumber()}`);
        console.log(`User3: ${(await web3.eth.getBalance(accounts[3])).toNumber()}`);
        console.log(`User4: ${(await web3.eth.getBalance(accounts[4])).toNumber()}`);
        console.log(`Sale : ${(await web3.eth.getBalance(sale.address)).toNumber()}`);
        console.log(`Token: ${(await web3.eth.getBalance(token.address)).toNumber()}`);


        console.log("--------------");
        console.log("");
    },

    toEther : toEther,

    toBee : toEther,

    oneEther : toEther(1),
    twoEther : toEther(2),
    threeEther : toEther(3),
    tenEther : toEther(10),
    hundredEther : toEther(100),

    GAS_LIMIT_IN_WEI: 50000000000
}