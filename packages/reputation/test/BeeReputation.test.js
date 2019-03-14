const BeeReputation = artifacts.require("BeeReputation");
const SimpleBeeScorer = artifacts.require("SimpleBeeScorer");
const util = require("./util.js");

contract('BeeReputation Tests', function (accounts) {
    const owner = accounts[0];
    const host = accounts[1];
    const guest = accounts[2];

    let reputation;
    let scorer;

    beforeEach(async function () {
      reputation = await BeeReputation.new({from: owner});
      scorer = await SimpleBeeScorer.new({from: host});
    });

    it("calls to addSignal should properly update scores", async function () {
      // first signal (review type)
      await reputation.addSignal(host, guest, 0, 0x1, 0xdada, 100, {from: owner});
      let summary = await util.cleansePullReputationScore(
                    reputation.pullReputationScore(guest, {from: owner})
                );
      assert.equal(summary.userScore, 100, 'basic addSignal did not compute correct score (100)');
      assert.equal(summary.reviewCount, 1, 'basic addSignal did not compute correctly update review summaries');
      assert.equal(summary.reviewTotal, 100, 'basic addSignal did not compute correctly update review summaries');
      // second signal (review type)
      await reputation.addSignal(host, guest, 0, 0x2, 0xdadaba, 0, {from: owner});
      summary = await util.cleansePullReputationScore(
                    reputation.pullReputationScore(guest, {from: owner})
                );
      assert.equal(summary.userScore, 50, 'basic addSignal did not compute correct score (50)');
      assert.equal(summary.reviewCount, 2, 'basic addSignal did not compute correctly update review summaries');
      assert.equal(summary.reviewTotal, 100, 'basic addSignal did not compute correctly update review summaries');
      // thrid signal (misc type)
      await reputation.addSignal(host, guest, 3, 0x3, 0xdadababa, 100, {from: owner});
      summary = await util.cleansePullReputationScore(
                    reputation.pullReputationScore(guest, {from: owner})
                );
      assert.equal(summary.userScore, 66, 'basic addSignal did not compute correct score');
      assert.equal(summary.reviewCount, 2, 'basic addSignal did not compute correctly update review summaries');
      assert.equal(summary.reviewTotal, 100, 'basic addSignal did not compute correctly update review summaries');
      assert.equal(summary.miscCount, 1, 'basic addSignal did not compute correctly update misc summaries');
      assert.equal(summary.miscTotal, 100, 'basic addSignal did not compute correctly update misc summaries');
    });


    it("updateReputationScore should properly update user scores", async function () {
      await reputation.addSignal(host, guest, 0, 0x1, 0xdada, 100, {from: owner});
      let summary = await util.cleansePullReputationScore(
                    reputation.pullReputationScore(guest, {from: owner})
                );
      assert.equal(summary.userScore, 100, 'addSignal did not compute correct score (100)');
      // update scorer and user scores
      await reputation.updateReputationScore(scorer.address, {from: owner});
      // fetch new scores with simple scorer (which relies only on personalTotal and personalCount
      summary = await util.cleansePullReputationScore(
                    reputation.pullReputationScore(guest, {from: owner})
                );
      assert.equal(summary.userScore, 0, 'new scorer did not correct compute score (0)');
      
      // add signal for personal signal type
      await reputation.addSignal(host, guest, 1, 0x2, 0xdadababa, 20, {from: owner});
      // fetch new scores
      summary = await util.cleansePullReputationScore(
                    reputation.pullReputationScore(guest, {from: owner})
                );
      assert.equal(summary.userScore, 20, 'new scorer did not correct compute score (0)');
      assert.equal(summary.personalCount, 1, 'addSignal did not compute correctly update personal summaries');
      assert.equal(summary.personalTotal, 20, 'addSignal did not compute correctly update personal summaries');

    });
})
