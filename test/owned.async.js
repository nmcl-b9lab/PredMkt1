// Updated first ever test code to use async, await. Much easier to write and read!
// See some limitations at https://medium.com/@bluepnume/even-with-async-await-you-probably-still-need-promises-9b259854c161
// And some other examples at https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/test/BasicToken.js

var Qn = artifacts.require("./Owned.sol");

contract('Owned', function(accounts) {
  it("should have a public owner", async function() {
    let instance = await Qn.deployed();
    let owner = await instance.owner.call({from: accounts[1]});
    assert.equal(owner, accounts[0], "accounts[0] wasn't in the first account");
  });

  it("should allow owner change as a call", async function() {
      let instance = await Qn.deployed();
      let res = await instance.changeOwner.call(accounts[1], {from: accounts[0]});
      assert.isTrue(res, "owner change should be successful");
  });
  
  it("should allow owner change as a trx", async function() {
    let instance = await Qn.deployed();
    let trx = await instance.changeOwner(accounts[1], {from: accounts[0]});
    //console.log(JSON.stringify(trx, null, 2));
    let owner = await instance.owner.call({from: accounts[1]});
    assert.equal(owner, accounts[1], "accounts[1] wasn't in the second account");
  });

});
