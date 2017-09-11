pragma solidity 0.4.15;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/PausableByOwner.sol";
import "../contracts/PredictionMarketHub.sol";

contract TestPredictionMarketHub {

  // TODO: this test uses test accounts, as follows:
  // 0 - Hub owner
  // 1 - qn sponsor
  // 2 - trusted oracle
  // 3 - alternate owner
  // 4&5 - YES proposals
  // 6&7 - NO proposals

  // QUESTION: When to use solidity tests, and when to use JS tests? I appreciate that
  // the situation is dynamic but what's the current best practice? I find solidity tests
  // more intuitive (perhaps becasue I am not a Javascript dev, I have to think hard
  // about Promises). I suspect they are also more limited but I might not be using them
  // correctly. Is there a list somewhere
  // of the ways in which solidity tests really are limited

  // QUESTION: how to test things like timestamps (not block numbers)? can time be mocked?
  // ANSWER?: See https://ethereum.stackexchange.com/questions/15596/how-can-i-mock-the-time-for-solidity-tests/15650

  // QUESTION: how to access testrpc or geth account addresses for the above.
  // Read somethign about passing them in as arguments to a migration, but I don't know that
  // I want to migrate this contract becasue it's a test contract? If I do need to do it
  // that way, how to access them during migrations?

  // Truffle will send the TestContract one Ether after deploying the contract.
  uint public initialBalance = 1 ether;

  function testInitialQuestion() {
    PredictionMarketHub hub = PredictionMarketHub(DeployedAddresses.PredictionMarketHub());

    Assert.equal(hub.balance, 0, "Hub should have 0 Ether initially");
    Assert.equal(hub.owner(), tx.origin, "Hub should have 0 Ether initially");

    PredictionMarketQuestionBase qn = PredictionMarketQuestionBase(hub.createPredictionMarketQuestion());

    // QUESTION: the below is complaining about the nunber of params. (How) can I specify things like 
    // a value and sender when invoking the function calls under test?
    qn.predictYes.sendTransaction({value: 100});
    qn.predictNo.sendTransaction({value: 200});


    Assert.equal(qn.totalCollectedWei(), 500);
  }
/*
  function testInitialBalanceWithNewMetaCoin() {
    MetaCoin meta = new MetaCoin();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially");
  }*/

}
