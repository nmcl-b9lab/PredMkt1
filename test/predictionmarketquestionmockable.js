// Updated first ever test code to use async, await. Much easier to write and read!
// See some limitations at https://medium.com/@bluepnume/even-with-async-await-you-probably-still-need-promises-9b259854c161
// And some other examples at https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/test/BasicToken.js

var Qn = artifacts.require("./PredictionMarketQuestionMockable.sol");

contract('PredictionMarketQuestionMockable', function(accounts) {

  var instance;
  var DEADLINE_TIMESTAMP = 1506729600;
  var sponsor = accounts[1];
  var oracle = accounts[2];

  beforeEach("get instance", async function() {
    //instance = await Qn.deployed();
    instance = await Qn.new(
      sponsor,
      "African or European swallow?",
      oracle,
      DEADLINE_TIMESTAMP
      //,{gas: 1000000}
    ); // ~ End of Sep 2017
  });

  it("has a public owner", async function() {
    let owner = await instance.owner.call({from: accounts[1]});
    assert.equal(owner, accounts[0], "accounts[0] wasn't in the first account");
  });

  it("allows owner change as a call", async function() {
    let res = await instance.changeOwner.call(accounts[1], {from: accounts[0]});
    assert.isTrue(res, "owner change should be successful");
  });

  it("allows owner change as a trx", async function() {
    let trx = await instance.changeOwner(accounts[1], {from: accounts[0]});
    //console.log(JSON.stringify(trx, null, 2));
    let owner = await instance.owner.call({from: accounts[1]});
    assert.equal(owner, accounts[1], "accounts[1] wasn't in the second account");
  });

  it("starts life unresolved", async function() {
    let res = await instance.resolved.call({from: accounts[0]});
    assert.equal(false, res, "instance is unresolved");
  });

  it("starts life open for predictions", async function() {
    let res = await instance.isOpenForPredictions.call();
    let closingTime = await instance.closesToPredictionsAtTimestamp.call();
    let currentTime = await instance.currentTime.call();
    //console.log(closingTime.toString(),currentTime.toString(),res);
    assert.equal(true, res, "instance is not open for predictions");
  });

  it("updates the balance on payments", async function() {    
    let trx1Promise = instance.predictYes({from: accounts[4], value: 10});
    let trx2Promise = instance.predictNo({from: accounts[3], value: 25});
    await Promise.all([trx1Promise, trx2Promise]);    
    let sumWei = await instance.totalCollectedWei.call({from: accounts[1]});    
    assert.equal(sumWei.toString(), 35, "all funds accounted for");
  });

  it("pays out as exepcted (test case 1 of many!)", async function() {    
    let trx1Promise = instance.predictYes({from: accounts[5], value: 10000});
    let trx2Promise = instance.predictNo({from: accounts[3], value: 45000});
    let trx3Promise = instance.predictYes({from: accounts[4], value: 5000});
    await Promise.all([trx1Promise, trx2Promise, trx3Promise]);    
    let sumWei = await instance.totalCollectedWei.call({from: accounts[1]});    
    assert.equal(sumWei.toString(), 60000, "all funds accounted for");

    await instance.setCurrentTime(DEADLINE_TIMESTAMP + 1);
    await instance.resolve(1, {from: oracle}); // YES

    console.log("foo");
    console.log(instance.contract.address);
    console.log("bar");
    let payoutMult = await instance.payoutMultiplierInBasisPoints.call();
    // Expect ((total bids - commission) / winning bids) * 1000
    // = 60 - 0.6 / 15 = 4 * 10000 = 39900
    assert.equal(payoutMult.toString(), 39600, "correct payout mult");    

    //let payout1 = await instance.payoutMultiplierInBasisPoints.call();

    
    let payout1 = await instance.claimPayout.call(accounts[5], {from:accounts[5]});
    assert.equal(payout1.toString(), 39600, "correct payout 1");

    //let payout2 = await instance.claimPayout.call(accounts[3], {from:accounts[5]});
    //assert.equal(payout2.toString(), 0, "correct payout 2");

    //let payout3 = await instance.claimPayout.call(accounts[4], {from:accounts[5]});
    //assert.equal(payout3.toString(), 20, "correct payout 3");
  });

  // Here is how we can group some tests to have a common beforeEach()
  /*describe("initialization tests", () => {
    beforeEach(async function() {
      SFTPOInstance = await ShopFrontTokenPriceOracle.new();
      SFInstance = await ShopFront.new(_shippingOracle, SFTPOInstance.address);
    })

    it("should create the active receipts with 1 element", async function() {
      let activeReceipts = (await SFInstance.getReceiptCount.call()).toNumber();
      assert.equal(activeReceipts, 1, "The count of active receipts should be 1 after creation!");
    });

    it("should throw if try to access index 0", async function() {
      await expectThrow(SFInstance.activeReceipts.call(0));
    });
  });*/

});
