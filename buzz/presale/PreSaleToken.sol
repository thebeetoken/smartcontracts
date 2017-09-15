pragma solidity ^0.4.17;

contract Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant returns (uint256 balance);
}


/*  ERC 20 token */
contract PreSaleToken is Token {
    

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }
    
    mapping (address => uint256) balances;

}
