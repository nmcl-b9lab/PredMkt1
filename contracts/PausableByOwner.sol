pragma solidity 0.4.15;

import './Owned.sol';

contract PausableByOwner is Owned() {
    bool public paused;
    event LogPause(string reason);
    event LogUnpause(string reason);

    function pause(string reason)
        onlyOwner
        returns(bool success)
    {
        require(!paused);
        paused = true;
        LogPause(reason);
        return true;
    }

    function unpause(string reason)
        onlyOwner
        returns(bool success)
    {
        require(paused);
        paused = false;
        LogUnpause(reason);
        return true;
    }

    modifier notWhilePaused()
    {
        require(!paused);
        _;
    }
}