pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract TestToken is StandardToken {
    using SafeMath for uint256;

    constructor(uint256 supply, address holder) public {
        totalSupply_ = supply;
        balances[holder] = supply;
    }

    function mint(uint256 tokens, address holder) public {
        totalSupply_ = totalSupply_.add(tokens);
        balances[holder] = balances[holder].add(tokens);
    }

    function burnAll(address holder) public {
        totalSupply_ = totalSupply_.sub(balances[holder]);
        balances[holder] = 0;
    }
}
