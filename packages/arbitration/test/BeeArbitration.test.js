const TestToken = artifacts.require("TestToken");
const BeeArbitration = artifacts.require("BeeArbitration");
const BeePayment = artifacts.require("BeePayment");
const util = require("./util.js");

contract('BeeArbitration Dispatch Test', function (accounts) {
    // account[0] points to the owner on the testRPC setup
    const arbOwner = accounts[0];
    const triggerman = accounts[1];
    const guest = accounts[2];
    const host = accounts[3];
    const miner1 = accounts[4];
    const miner2 = accounts[5];
    const miner3 = accounts[6];
    const miner4 = accounts[7];
    const miner5 = accounts[8];

    const otherOwner = accounts[9];
    


    const disputeAmount = 200000000000000000;
    let token;
    let payment;
    let arbitration;
    let arbitrationFee;
    let normStakeAmount;
    let minStakeAmount;


    beforeEach(async function () {
      token = await TestToken.new('1000000000000000000000000000', otherOwner, { from: otherOwner});
      arbitration = await BeeArbitration.new(token.address, {from: arbOwner,  gas: 80000000 });
      payment = await BeePayment.new(token.address, arbitration.address, { from: otherOwner});
      
      const balance = await token.balanceOf(guest);
      await Promise.all([...accounts, arbitration.address].map(
        address => token.burnAll(address)
      ));
      arbitrationFee = await arbitration.normArbFee();
      minStakeAmount =  await arbitration.minMiningStake();
      normStakeAmount = minStakeAmount*2;
      await token.mint(normStakeAmount*2, miner1);
      await token.mint(normStakeAmount*2, miner2);
      await token.mint(normStakeAmount*2, miner3);
      await token.mint(normStakeAmount*2, miner4);
      await token.mint(normStakeAmount*2, miner5);
      
      let total =  (arbitrationFee + disputeAmount)*2;
      await token.mint(total, guest);
      await token.transfer(payment.address, total, { from: guest });
      
      await token.mint(normStakeAmount*2, guest);
      await token.mint(normStakeAmount*2, host);
    });
  
    async function fastForward(seconds) {
      await send('evm_increaseTime', [seconds]);
      await send('evm_mine');
    }

  it("check functionality of transferToken, trasnfer with no bee promised", async function () {
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

    let arbOwnerBefore = await token.balanceOf(arbOwner); 
    let total = 3333;
    await token.mint(total, guest);
    await token.transfer(arbitration.address, total, { from: guest });
    await arbitration.transferToken(token.address, arbOwner, total, {from: arbOwner});
    
    let arbOwnerAfter = await token.balanceOf(arbOwner); 
    assert.equal(arbOwnerBefore.valueOf() == arbOwnerAfter.valueOf() + total, false, "basic transfer didn't work"); 
  });
  
  it("check functionality of transferToken, see if admin can steal from miner stakes", async function () {
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

    let total = 3333;
    await token.mint(total, guest);
    await token.transfer(arbitration.address, total, { from: guest });
  

    //put miner 1 in queue
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.approveMiner(1, { from: arbOwner }); 
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await arbitration.startMining(normStakeAmount, { from: miner1 });
   
    total = total +1;
    await util.assertRevert(
      arbitration.transferToken(token.address, arbOwner, total, {from: arbOwner})
    );
  });

  it("check functionality of transferToken, see if admin can steal from an arbitration job", async function () {
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

    let total = 3333;
    await token.mint(total, guest);
    await token.transfer(arbitration.address, total, { from: guest });

    //have dispute amount in there
    let paymentId = '0xdeadbeef00000000000000000000000000000000000000000000000000000000';
    await payment.sendArbitrationRequest(guest, host, disputeAmount, paymentId);

    await arbitration.startMining(normStakeAmount, { from: miner5 });

    total = total +1;
    await util.assertRevert(
      arbitration.transferToken(token.address, arbOwner, total, {from: arbOwner})
    );
  });
  
  it("check onlyOwner and functionality of function:addContractAddress", async function () {
    let addressIsSet = await arbitration.whiteListedContracts(payment.address); 
    assert.equal(addressIsSet, false);
    await util.assertRevert(
      arbitration.addContractAddress(payment.address, { from: triggerman })
    );

    addressIsSet = await arbitration.whiteListedContracts(payment.address); 
    assert.equal(addressIsSet, false);
    await arbitration.addContractAddress(payment.address, { from: arbOwner });
    
    
    addressIsSet = await arbitration.whiteListedContracts(payment.address); 
    assert.equal(addressIsSet, true);
    

  });

  it("check onlyOwner and functionality of function:removeContractAddress", async function () {
    await arbitration.addContractAddress(payment.address, { from: arbOwner });

    let addressIsSet = await arbitration.whiteListedContracts(payment.address); 
    assert.equal(addressIsSet, true);
    await util.assertRevert(  
      arbitration.removeContractAddress(payment.address, { from: triggerman })
    );                        
                              
    addressIsSet = await arbitration.whiteListedContracts(payment.address);     
    assert.equal(addressIsSet, true);
    await arbitration.removeContractAddress(payment.address, { from: arbOwner });
                              
                              
    addressIsSet = await arbitration.whiteListedContracts(payment.address);     
    assert.equal(addressIsSet, false);  
  });
  it("check startMining:", async function () {
    //check there are no miners
    await util.assertErrorThrown(
      arbitration.existingArbiters(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //check start mining reverts because contract is not activated
    await util.assertRevert(                              
      arbitration.startMining(normStakeAmount, { from: miner1 })
    );  

    //activate contract
    await arbitration.activateContract({ from: arbOwner });
    
    //check there are no miners
    await util.assertErrorThrown(
      arbitration.existingArbiters(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //start mining
    await arbitration.startMining(normStakeAmount, { from: miner1 })

    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    let minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '0'); //check miner state is init to pending (0)
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address

  });
  
  it("check stopMining:", async function () {
   //check there are no miners
    await util.assertErrorThrown(
      arbitration.existingArbiters(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //check start mining reverts because contract is not activated
    await util.assertRevert(
      arbitration.startMining(normStakeAmount, { from: miner1 })
    );

    //activate contract
    await arbitration.activateContract({ from: arbOwner });

    //check there are no miners
    await util.assertErrorThrown(
      arbitration.existingArbiters(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });

    //start mining
    await arbitration.startMining(normStakeAmount, { from: miner1 })
    
    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    let minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '0'); //check miner state is init to pending (0)
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first
    assert.equal(minerDat[3], '0'); //make sure we haven't recorded a stake 

    //cancel approve stake amount because miner isn't allowed to mine yet UI will do this so we mimic
    await token.approve(arbitration.address, 0, { from: miner1 });
    
    //double check we are not in mining queue and stop fails because we are not in the mining queue yet
    await util.assertRevert(
      arbitration.stopMining({ from: miner1 })
    );

    //approve miner
    await arbitration.approveMiner(1, { from: arbOwner });
  
    //approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });
 
    //get in mining queue
    await arbitration.startMining(normStakeAmount, { from: miner1 })

    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check miner state is init to pending (0)
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '1'); //check mining index id is set to 0, not mining yet, needs approval first
    assert.equal(minerDat[3], normStakeAmount); //make sure we recorded a stake 

    //check to see if there is a miner is the mining queue and there index is set to 1
    let minerQueueDat = await arbitration.arbitersMining(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check current index is equal to 1 which is the current miner's index

    //stop mining
    await arbitration.stopMining({ from: miner1 })


    //check there are no miners in the mining queue, they should still be in the existingArbiter array though
    await util.assertErrorThrown(
      arbitration.arbitersMining(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //check that miner state is correct and miner is still in existingArbiter array
    minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check miner state is still set to approved 
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining 
    assert.equal(minerDat[3], '0'); //make sure we haven't recorded a stake 
  });
 
  it("check approveMiner:", async function () {
    
    //activate contract
    await arbitration.activateContract({ from: arbOwner });
    
    //check there are no miners
    await util.assertErrorThrown(
      arbitration.existingArbiters(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //add miner to existing miner list
    await arbitration.startMining(normStakeAmount, { from: miner1 })



    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    let minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '0'); //check miner state is init to pending (0)
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first
    assert.equal(minerDat[3], '0'); //make sure we haven't recorded a stake
  
    //approve miner 
    await arbitration.approveMiner(1, { from: arbOwner });
  
  
    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check miner state was set to 1 - approved
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first


    //get in mining queue
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await arbitration.startMining(normStakeAmount, { from: miner1 })
  
    //check to see if there is a miner is the mining queue and there index is set to 1
    let minerQueueDat = await arbitration.arbitersMining(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check current index is equal to 1 which is the current miner's index
  });

  it("check banMiner:", async function () {
     //activate contract
    await arbitration.activateContract({ from: arbOwner });

    //check there are no miners
    await util.assertErrorThrown(
      arbitration.existingArbiters(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //add miner to existing miner list
    await arbitration.startMining(normStakeAmount, { from: miner1 })



    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    let minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '0'); //check miner state is init to pending (0)
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first
    assert.equal(minerDat[3], '0'); //make sure we haven't recorded a stake

    //approve miner                            
    await arbitration.approveMiner(1, { from: arbOwner });
                                               
                                               
    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check miner state was set to 1 - approved
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first
   

    //get in mining queue
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await arbitration.startMining(normStakeAmount, { from: miner1 })
  
    //check to see if there is a miner is the mining queue and there index is set to 1
    let minerQueueDat = await arbitration.arbitersMining(1, { from: triggerman });
    assert.equal(minerDat[0], '1'); //check current index is equal to 1 which is the current miner's index
    
    //ban miner
    await arbitration.banMiner(1, { from: arbOwner });

    //check there is a miner in location 1 and the miner is not approved yet and miner address is miner 1s address
    minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '2'); //check miner state was set to 2 - banned
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first
 
    //check there are no miners in the mining queue, they should still be in the existingArbiter array though
    await util.assertErrorThrown(
      arbitration.arbitersMining(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );

    //check start mining won't give them a revert or error but also won't let them start mining 
    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    arbitration.startMining(normStakeAmount, { from: miner1 })
    minerDat = await arbitration.existingArbiters(1, { from: triggerman });
    assert.equal(minerDat[0], '2'); //check miner state was set to 2 - banned
    assert.equal(minerDat[1], miner1); //check miner who registered has the correct address
    assert.equal(minerDat[2], '0'); //check mining index id is set to 0, not mining yet, needs approval first
  
    //check there are no miners in the mining queue, they should still be in the existingArbiter array though
    await util.assertErrorThrown(
      arbitration.arbitersMining(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );
  
  });
  it("check arbitrationVote", async function () {
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

//request arbitration
    //check no arbitration job is set yet
    await util.assertErrorThrown(
      arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );
    let paymentId = '0xdeadbeef00000000000000000000000000000000000000000000000000000000';
    await payment.sendArbitrationRequest(guest, host, disputeAmount, paymentId);
    
    //check arbitration job is in there
    let jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let timeRequested = jobDat[2];
    let minMinerTime = jobDat[3];
    let maxMinerTime = jobDat[4];
    assert.equal(jobDat[0], 0, "parent arb job id should be 0");//parent job id (if we paid for an appeal, this would be the original job id created)
    assert.equal(jobDat[1],  paymentId, "payment ids don't match");
    //assert.equal(jobDat[6], arbitrationFee); //TODO for some reason bigInt can't compare to bigInt, fix later
    assert.equal(jobDat[7], disputeAmount, "dispute amount doesn't match");
    assert.equal(jobDat[8], host, "host address doesn't match");
    assert.equal(jobDat[9], guest, "guest address doesn't match");

//put 5 miners up in queue
    //register miners
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });

    //approve contract owner approves miners
    await arbitration.approveMiner(1, { from: arbOwner }); 
    await arbitration.approveMiner(2, { from: arbOwner }); 
    await arbitration.approveMiner(3, { from: arbOwner }); 
    await arbitration.approveMiner(4, { from: arbOwner }); 
    await arbitration.approveMiner(5, { from: arbOwner }); 

    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner2 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner3 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner4 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner5 });//approve stake
    
    //put miner in queue
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });

    //check no arbVotes assigned but 5 created
    for (var i = 1; i<6; i++) {
      let curVoteDat = await arbitration.arbVotes(i, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
      assert.equal(curVoteDat[0], 0, "default vote state value should be unassigned (0)"); //make sure state is 0, unassigned to arbiter
      assert.equal(curVoteDat[1], 0, "default vote should be 0"); //make sure vote is set to 0 as default although not really nessary
      assert.equal(curVoteDat[2], 1, "default job id assigned incorrectly to job"); //make sure jobsid is set to 1 because the job we created should be the 1st real job in the queue (after dummy job)
      assert.equal(curVoteDat[3], 0, "arbiter id should be 0 unassigned by default"); //make sure arbiterId assigned to vote is currently 0 because no arbiter should be assigned yet 
    }

    //arbiters try to vote and fail because it's not yet time to vote
    let voteId1 = 1;
    let voteCasted1 = 2;
    await util.assertRevert(
      arbitration.arbitrationVote(voteId1, voteCasted1)
    );

//fast forward time past min mining time
//    var n = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
//    console.log("curblock time: "+n);
//let timeNeededToWaitForDisputeAppeal = minMinerTime - timeRequested;
    let timeNeededToWaitToActivateJob = (minMinerTime - timeRequested)+1;
    await util.timeTravelInSeconds(timeNeededToWaitToActivateJob);
  
//have triggerman trigger job so votes are assigned to miners
    let nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    assert.equal(nextNeededJobToTrigger, 1, "job needed to trigger was job 1");
    let triggermanBalanceBeforeTrigger = await token.balanceOf(triggerman); 
    let arbitrationFeeBeforeTrigger = jobDat[6];
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});

//check triggerman's balanceOf bee tokens to make sure triggerman got paid
    let triggermanBalanceAfterTrigger = await token.balanceOf(triggerman); 
    assert.equal(triggermanBalanceBeforeTrigger < triggermanBalanceAfterTrigger, true, "triggerman not paid for first trigger");
//check to see that beeArbitrationFee got reduced by triggerman's pay
    jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }); //should be 1 dummy at index 0, 1 is the next location a miner can go
    assert.equal(jobDat[6]< arbitrationFeeBeforeTrigger, true, "arbitration fee needs to be reduced after paying triggerman"); 
    nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});

    
//    for (var i = 1; i<6; i++) {
//      let curVoteDat = await arbitration.arbVotes(i, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
//      console.log("curVote: "+curVoteDat);
//    }
    assert.equal(nextNeededJobToTrigger, 0, "already triggerd job but asked to do so again"); 

//check only miners assigned to those votes can vote, try to get a miner not assigned to a vote to vote for it
    let voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner1 }); 
    await util.assertRevert(
      arbitration.arbitrationVote(voteIdForVoteToComplete, voteCasted1, {from:miner2})
    );

//check for revert if voter tries to vote for something outside bounds
    await util.assertRevert(
      arbitration.arbitrationVote(voteIdForVoteToComplete, 55, {from:miner1})
    );

//check vote gets registered right
    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner1 }); 
    await arbitration.arbitrationVote(voteIdForVoteToComplete, voteCasted1, {from:miner1});
    let voteDatForMiner1 = await arbitration.arbVotes(voteIdForVoteToComplete, { from: triggerman }); 
    assert.equal(voteDatForMiner1[0], 2, "vote state should be set to vote complete (2)");
    assert.equal(voteDatForMiner1[1], voteCasted1, "the vote casted does not equal the vote recorded on the server");
    assert.equal(voteDatForMiner1[2], 1, "vote did not record vote for arbitration job 1");
    assert.equal(voteDatForMiner1[3], 1, "miner 1 has arbiter id 1, the vote we voted on does not have arbiter id = 1");

//check change vote
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 3, {from:miner1});
    voteDatForMiner1 = await arbitration.arbVotes(voteIdForVoteToComplete, { from: triggerman }); 
    assert.equal(voteDatForMiner1[1], 3, "contract did not record changed vote");

//have all arbiters vote  0,0,0,1,1 = 50%/5 = 10% dispute goes to 1 person
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner1});
    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner2 }); 
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner2});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner3 }); 
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner3});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner4 }); 
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner4});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner5 }); 
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner5});


    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner1 }); 
    assert.equal(voteIdForVoteToComplete, 0, "no more votes to complete for miner 1, should be 0 but is not 0"); 

  });
  it("check request Arbitration all miners voted", async function () {
//create job and have all miners vote
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

    //check no arbitration job is set yet
    await util.assertErrorThrown(
      arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );
    let paymentId = '0xdeadbeef00000000000000000000000000000000000000000000000000000000';
    await payment.sendArbitrationRequest(guest, host, disputeAmount, paymentId);
    
    let jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let timeRequested = jobDat[2];
    let minMinerTime = jobDat[3];

    //register miners
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });

    //approve contract owner approves miners
    await arbitration.approveMiner(1, { from: arbOwner });
    await arbitration.approveMiner(2, { from: arbOwner });
    await arbitration.approveMiner(3, { from: arbOwner });
    await arbitration.approveMiner(4, { from: arbOwner });
    await arbitration.approveMiner(5, { from: arbOwner });

    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner2 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner3 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner4 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner5 });//approve stake

    //put miner in queue
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });
    
    var curBlockTime = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let timeNeededToWaitToActivateJob = (minMinerTime - curBlockTime)+1;
    await util.timeTravelInSeconds(timeNeededToWaitToActivateJob);

    //have triggerman trigger job so votes are assigned to miners
    let nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});
   
    //have all arbiters vote  0,0,0,1,1 = 50%/5 = 10% dispute goes to 1 person
    let voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner1 }); 
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner1});
    
    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner2 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner2});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner3 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner3});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner4 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner4});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner5 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner5});

//fast forward time past max miner time
    jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let maxMinerTime = jobDat[4];
    curBlockTime = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let timeNeededToWaitForEndMinerVote = (maxMinerTime - curBlockTime)+1;
    await util.timeTravelInSeconds(timeNeededToWaitForEndMinerVote);
    //have triggerman trigger next state waiting for appeal 
    nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});


    //make sure miners can't arbirate after max miner time is completed
    await util.assertRevert(
      arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner5})
    );

let triggermanBalanceBeforeTrigger = await token.balanceOf(triggerman); 
let guestBalanceBeforeTrigger = await token.balanceOf(guest); 
let hostBalanceBeforeTrigger = await token.balanceOf(host); 
let miner1BalanceBeforeTrigger = await token.balanceOf(miner1); 
let miner2BalanceBeforeTrigger = await token.balanceOf(miner2); 
let miner3BalanceBeforeTrigger = await token.balanceOf(miner3); 
let miner4BalanceBeforeTrigger = await token.balanceOf(miner4); 
let miner5BalanceBeforeTrigger = await token.balanceOf(miner5); 

//fast forward time past appeal time
    jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    curBlockTime = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let appealTimelimit = jobDat[5];
    let timeNeededToWaitForEndAppealTime = (appealTimelimit - curBlockTime)+1;
    await util.timeTravelInSeconds(timeNeededToWaitForEndAppealTime);
    //have triggerman trigger next state, appeal wait complete, run render judgement
    nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});


//make sure miners can't arbirate after max miner time is completed
    await util.assertRevert(
      arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner5})
    );

//check to see if funds get dispersed to host / guest / arbiters correctly
let triggermanBalanceAfterTrigger = await token.balanceOf(triggerman); 
let guestBalanceAfterTrigger = await token.balanceOf(guest); 
let hostBalanceAfterTrigger = await token.balanceOf(host); 
let miner1BalanceAfterTrigger = await token.balanceOf(miner1); 
let miner2BalanceAfterTrigger = await token.balanceOf(miner2); 
let miner3BalanceAfterTrigger = await token.balanceOf(miner3); 
let miner4BalanceAfterTrigger = await token.balanceOf(miner4); 
let miner5BalanceAfterTrigger = await token.balanceOf(miner5); 
assert.equal(triggermanBalanceBeforeTrigger < triggermanBalanceAfterTrigger, true, "triggerman  not paid for render judgement trigger");
assert.equal(miner1BalanceBeforeTrigger < miner1BalanceAfterTrigger, true, "miner1 not paid for render judgement vote");
assert.equal(miner2BalanceBeforeTrigger < miner2BalanceAfterTrigger, true, "miner2 not paid for render judgement vote");
assert.equal(miner3BalanceBeforeTrigger < miner3BalanceAfterTrigger, true, "miner3 not paid for render judgement vote");
assert.equal(miner4BalanceBeforeTrigger < miner4BalanceAfterTrigger, true, "miner4 not paid for render judgement vote");
assert.equal(miner5BalanceBeforeTrigger < miner5BalanceAfterTrigger, true, "miner5 not paid for render judgement vote");
let disputeAmt = jobDat[7];
let hostRulingSupposeToBe = disputeAmt * .1;
let guestRulingSupposeToBe = disputeAmt - hostRulingSupposeToBe;
let hostGain = hostBalanceAfterTrigger - hostBalanceBeforeTrigger;
let guestGain = guestBalanceAfterTrigger - guestBalanceBeforeTrigger;

assert.equal(guestRulingSupposeToBe, guestGain , "guest not accurately paid for render judgement");
assert.equal(hostRulingSupposeToBe, hostGain, "host not accurately paid for render judgement");


  });
  it("check request Arbitration two miners didn't vote", async function () {
//create job and have all miners vote
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

    //check no arbitration job is set yet
    await util.assertErrorThrown(
      arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );
    let paymentId = '0xdeadbeef00000000000000000000000000000000000000000000000000000000';
    await payment.sendArbitrationRequest(guest, host, disputeAmount, paymentId);
    
    let jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let timeRequested = jobDat[2];
    let minMinerTime = jobDat[3];
    
    //register miners
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });
    await arbitration.startMining(normStakeAmount, { from: guest });
    await arbitration.startMining(normStakeAmount, { from: host });

    //approve contract owner approves miners
    await arbitration.approveMiner(1, { from: arbOwner });
    await arbitration.approveMiner(2, { from: arbOwner });
    await arbitration.approveMiner(3, { from: arbOwner });
    await arbitration.approveMiner(4, { from: arbOwner });
    await arbitration.approveMiner(5, { from: arbOwner });
    await arbitration.approveMiner(6, { from: arbOwner });
    await arbitration.approveMiner(7, { from: arbOwner });

    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner2 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner3 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner4 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner5 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: guest });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: host });//approve stake

    //put miner in queue
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });

    let timeNeededToWaitToActivateJob = (minMinerTime - timeRequested)+1;
    await util.timeTravelInSeconds(timeNeededToWaitToActivateJob);
    //have triggerman trigger job so votes are assigned to miners
    let nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});
    //create job and have 3 miners vote
    let voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner1 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner1});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner2 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner2});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner3 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner3});

//fast forward time past max miner time
    jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let maxMinerTime = jobDat[4];
    curBlockTime = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let timeNeededToWaitForEndMinerVote = (maxMinerTime - curBlockTime)+1;
    await util.timeTravelInSeconds(timeNeededToWaitForEndMinerVote);

//register 2 more voters because miner 4 and 5 are gonna get booted
    await arbitration.startMining(normStakeAmount, { from: guest });
    await arbitration.startMining(normStakeAmount, { from: host });

    //save balances
let guestBalanceBeforeTrigger = await token.balanceOf(guest); 
let hostBalanceBeforeTrigger = await token.balanceOf(host); 
let miner1BalanceBeforeTrigger = await token.balanceOf(miner1); 
let miner2BalanceBeforeTrigger = await token.balanceOf(miner2); 
let miner3BalanceBeforeTrigger = await token.balanceOf(miner3); 
let miner4BalanceBeforeTrigger = await token.balanceOf(miner4); 
let miner5BalanceBeforeTrigger = await token.balanceOf(miner5); 

    //have triggerman trigger next state waiting for appeal 
    nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});
                                                         
    //check to see if job state gets put back to in progress
    jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    
    curBlockTime = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    assert.equal(jobDat[0], 0, "parent arb job id should be 0");//parent job id (if we paid for an appeal, this would be the original job id created)
    assert.equal(jobDat[1],  paymentId, "payment ids don't match");
    assert.equal(jobDat[7], disputeAmount, "dispute amount doesn't match");
    assert.equal(jobDat[8], host, "host address doesn't match");
    assert.equal(jobDat[9], guest, "guest address doesn't match");

    let jobInProgressId = nextNeededJobToTrigger = await arbitration.jobsInProgress(1, {from: triggerman});
    assert.equal(jobInProgressId, 1, "when miner did not vote and max miner time elapsed, job got taken out of jobInProgressPool");
    
    let voteDatGuest = await arbitration.arbVotes(6, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    assert.equal(voteDatGuest[0], 1, "guest vote status is not 1, pending vote");
    let voteDatHost = await arbitration.arbVotes(7, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    assert.equal(voteDatHost[0], 1, "host vote status is not 1, pending vote");
    
    //make sure miner 4 and miner 5 gets penalized for not voting
    //make sure no one gets paid

let guestBalanceAfterTrigger = await token.balanceOf(guest);
let hostBalanceAfterTrigger = await token.balanceOf(host);
let miner1BalanceAfterTrigger = await token.balanceOf(miner1);
let miner2BalanceAfterTrigger = await token.balanceOf(miner2);
let miner3BalanceAfterTrigger = await token.balanceOf(miner3);
let miner4BalanceAfterTrigger = await token.balanceOf(miner4);
let miner5BalanceAfterTrigger = await token.balanceOf(miner5);
assert.equal(miner1BalanceBeforeTrigger.valueOf() == miner1BalanceAfterTrigger.valueOf(), true, "miner1 should have same amount after non voters cause vote delay");
assert.equal(miner2BalanceBeforeTrigger.valueOf() ==  miner2BalanceAfterTrigger.valueOf(), true, "miner2 should have same amount after non voters cause vote delay");
assert.equal(miner3BalanceBeforeTrigger.valueOf() == miner3BalanceAfterTrigger.valueOf(), true, "miner3 should have same amount after non voters cause vote delay");
assert.equal(miner4BalanceBeforeTrigger+normStakeAmount > miner4BalanceAfterTrigger, true, "miner4 should have stake taken away");
assert.equal(miner5BalanceBeforeTrigger+normStakeAmount > miner5BalanceAfterTrigger, true, "miner5 should have stake taken away");
assert.equal(guestBalanceBeforeTrigger.valueOf(), guestBalanceAfterTrigger.valueOf() , "guest should not be paid after someone doesn't vote and a arbitration job delay happens");
assert.equal(hostBalanceBeforeTrigger.valueOf(), hostBalanceAfterTrigger.valueOf(), "host should not be paid after someone doesn't vote and a arbitration job delay happens");
                                                         

  });
  
  
  it("check request Arbitration Appeal", async function () {
//create job and have all miners vote
    await arbitration.activateContract({ from: arbOwner });//activate arbitration contract
    await arbitration.addContractAddress(payment.address, { from: arbOwner });//whitelist payment contract

    //check no arbitration job is set yet
    await util.assertErrorThrown(
      arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    );
    let paymentId = '0xdeadbeef00000000000000000000000000000000000000000000000000000000';
    await payment.sendArbitrationRequest(guest, host, disputeAmount, paymentId);

    let jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let timeRequested = jobDat[2];
    let minMinerTime = jobDat[3];
    
    //register miners
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });

    //approve contract owner approves miners
    await arbitration.approveMiner(1, { from: arbOwner });
    await arbitration.approveMiner(2, { from: arbOwner });
    await arbitration.approveMiner(3, { from: arbOwner });
    await arbitration.approveMiner(4, { from: arbOwner });
    await arbitration.approveMiner(5, { from: arbOwner });

    await token.approve(arbitration.address, normStakeAmount, { from: miner1 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner2 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner3 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner4 });//approve stake
    await token.approve(arbitration.address, normStakeAmount, { from: miner5 });//approve stake

    //put miner in queue
    await arbitration.startMining(normStakeAmount, { from: miner1 });
    await arbitration.startMining(normStakeAmount, { from: miner2 });
    await arbitration.startMining(normStakeAmount, { from: miner3 });
    await arbitration.startMining(normStakeAmount, { from: miner4 });
    await arbitration.startMining(normStakeAmount, { from: miner5 });

    let timeNeededToWaitToActivateJob = (minMinerTime - timeRequested)+1;
    await util.timeTravelInSeconds(timeNeededToWaitToActivateJob);
    //have triggerman trigger job so votes are assigned to miners
    let nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});

    //have all arbiters vote  0,0,0,1,1 = 50%/5 = 10% dispute goes to 1 person
    let voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner1 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner1});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner2 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner2});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner3 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 0, {from:miner3});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner4 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner4});

    voteIdForVoteToComplete = await arbitration.getMyFirstIncompletedVote( { from: miner5 });
    await arbitration.arbitrationVote(voteIdForVoteToComplete, 1, {from:miner5});

//fast forward time past max miner time
    jobDat = await arbitration.arbitrationJobs(1, { from: triggerman }) //should be 1 dummy at index 0, 1 is the next location a miner can go
    let maxMinerTime = jobDat[4];
    curBlockTime = await web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    let timeNeededToWaitForEndMinerVote = (maxMinerTime - curBlockTime)+1;
    await util.timeTravelInSeconds(timeNeededToWaitForEndMinerVote);
    //have triggerman trigger next state waiting for appeal 
    nextNeededJobToTrigger = await arbitration.checkTriggermanNextNeededJob({from: triggerman});
    await arbitration.triggerArbJob(nextNeededJobToTrigger, {from: triggerman});
                                                         

//save balances
let guestBalanceBeforeTrigger = await token.balanceOf(guest); 
let hostBalanceBeforeTrigger = await token.balanceOf(host); 
let miner1BalanceBeforeTrigger = await token.balanceOf(miner1); 
let miner2BalanceBeforeTrigger = await token.balanceOf(miner2); 
let miner3BalanceBeforeTrigger = await token.balanceOf(miner3); 
let miner4BalanceBeforeTrigger = await token.balanceOf(miner4); 
let miner5BalanceBeforeTrigger = await token.balanceOf(miner5);

    //have guest ask for appeal
    await token.mint(arbitrationFee*2, guest);//gonna cost 2x the normal arbitration fee
    await token.approve(arbitration.address, arbitrationFee*2, { from: guest });//approve stake
    await arbitration.requestAppeal(1, {from: guest}); //we know the prev arb id is 1

let guestBalanceAfterTrigger = await token.balanceOf(guest);
let hostBalanceAfterTrigger = await token.balanceOf(host);
let miner1BalanceAfterTrigger = await token.balanceOf(miner1);
let miner2BalanceAfterTrigger = await token.balanceOf(miner2);
let miner3BalanceAfterTrigger = await token.balanceOf(miner3);
let miner4BalanceAfterTrigger = await token.balanceOf(miner4);
let miner5BalanceAfterTrigger = await token.balanceOf(miner5);
assert.equal(miner1BalanceBeforeTrigger.valueOf() < miner1BalanceAfterTrigger.valueOf(), true, "miner1 should get paid if an appeal happens");
assert.equal(miner2BalanceBeforeTrigger.valueOf() <  miner2BalanceAfterTrigger.valueOf(), true, "miner2 should get paid if an appeal happens");
assert.equal(miner3BalanceBeforeTrigger.valueOf() < miner3BalanceAfterTrigger.valueOf(), true, "miner3 should get paid if an appeal happens");
assert.equal(miner4BalanceBeforeTrigger.valueOf() < miner4BalanceAfterTrigger.valueOf(), true, "miner4 should get paid if an appeal happens");
assert.equal(miner5BalanceBeforeTrigger.valueOf() < miner5BalanceAfterTrigger.valueOf(), true, "miner5 should get paid if an appeal happens");
assert.equal(guestBalanceBeforeTrigger.valueOf(), guestBalanceAfterTrigger.valueOf() , "guest should have same amount of tokens after guest appealed (not including appeal cost)");
assert.equal(hostBalanceBeforeTrigger.valueOf(), hostBalanceAfterTrigger.valueOf(), "host should have same amount of tokens after guest appealed decision");

jobDat = await arbitration.arbitrationJobs(2, { from: triggerman });
assert.equal(jobDat[0], 1, "parentId of appealed job should be 1 (the parent job id of current job)");

let jobIndex = await arbitration.jobsInProgress(1, { from: triggerman });
assert.equal(jobIndex, 2, "jobId of jobs in progress spot 1 shoudl be 2 because the previous job was removed from an appeal and the new job took it's place");

  });
});
