var Owned = artifacts.require("./Owned.sol");

contract('Owned', function(accounts) {
  it("should have a public owner", function() {
    return Owned.deployed().then(function(instance) {
      return instance.owner.call({from: accounts[1]});
    }).then(function(owner) {
      assert.equal(owner, accounts[0], "accounts[0] wasn't in the first account");
    });
  });

  it("should allow owner change as a call", function() {
    return Owned.deployed().then(function(instance) {
      return instance.changeOwner.call(accounts[1], {from: accounts[0]});
    }).then(function(res) {
      assert.isTrue(res, "owner change should be successful");
    });
  });
  
  it("should allow owner change as a trx", function() {
    return Owned.deployed().then(function(instance) {
      return instance.changeOwner(accounts[1], {from: accounts[0]});
    }).then(function(trx) {
      //console.log(JSON.stringify(trx, null, 2));
      return Owned.deployed().then(function(instance) {
        return instance.owner.call({from: accounts[1]});
        }).then(function(owner) {
        assert.equal(owner, accounts[1], "accounts[1] wasn't in the second account");
      })
    });
  });

});
