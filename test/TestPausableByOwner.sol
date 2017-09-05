pragma solidity 0.4.15;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/PausableByOwner.sol";

contract TestPausableByOwner {

  function testInitialOwnerUsingDeployedContract() {
    PausableByOwner PbO = PausableByOwner(DeployedAddresses.PausableByOwner());

    Assert.equal(PbO.balance, 0, "Owner should have 0 Ether initially");
  }
/*
  function testInitialBalanceWithNewMetaCoin() {
    MetaCoin meta = new MetaCoin();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially");
  }*/

}
