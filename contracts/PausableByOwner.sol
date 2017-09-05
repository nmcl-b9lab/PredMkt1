pragma solidity 0.4.15;

import './Owned.sol';

contract PausableByOwner is Owned() {
    bool public paused;
    event LogPause(string reason);
    event LogUnpause(string reason);

    function pause(string reason)
        onlyOwner
    {
        require(!paused);
        paused = true;
        LogPause(reason);
    }

    function unpause(string reason)
        onlyOwner
    {
        require(paused);
        paused = false;
        LogUnpause(reason);
    }

    modifier notWhilePaused()
    {
        require(!paused);
        _;
    }
}