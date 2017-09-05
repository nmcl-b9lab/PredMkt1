pragma solidity 0.4.15;

contract Owned {
    address public owner;
    event LogOwnerChange(address indexed oldOwner, address indexed newOwner);

    function Owned() {
        owner = msg.sender;
    }

    modifier onlyOwner()
    {
        require(owner == msg.sender);
        _;
    }

    function changeOwner(address newOwner)
        public
        onlyOwner
        returns (bool success)
    {
        require(newOwner != 0);
        LogOwnerChange(owner, newOwner);
        owner = newOwner;  
        return true;     
    }
}