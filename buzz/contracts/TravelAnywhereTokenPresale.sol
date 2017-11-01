pragma solidity ^0.4.17;
import "./PreSaleToken.sol";
import "./SafeMath.sol";

contract TravelAnywhereTokenPreSale is PreSaleToken {
    using SafeMath for uint256;

    uint256 public constant decimals = 18;
    
    bool public isEnded = false;
    address public contractOwner;
    address public travelAnywhereEthFund;
    uint256 public presaleStartBlock;
    uint256 public presaleEndBlock;
    uint256 public constant tokenExchangeRate = 620;
    uint256 public constant tokenCap = 62 * (10**6) * 10**decimals;
    
    event CreatePreSale(address indexed _to, uint256 _amount);
    
    function TravelAnywhereTokenPreSale(address _travelAnywhereEthFund, uint256 _presaleStartBlock, uint256 _presaleEndBlock)  public {
        travelAnywhereEthFund = _travelAnywhereEthFund;
        presaleStartBlock = _presaleStartBlock;
        presaleEndBlock = _presaleEndBlock;
        contractOwner = travelAnywhereEthFund;
        totalSupply = 0;
    }
    
    function () payable public {
        if (isEnded) revert();
        if (block.number < presaleStartBlock) revert();
        if (block.number > presaleEndBlock) revert();
        if (msg.value == 0) revert();
        
        uint256 tokens = msg.value.mul(tokenExchangeRate);
        uint256 checkedSupply = totalSupply.add(tokens);
        
        if (tokenCap < checkedSupply) revert();
        
        totalSupply = checkedSupply;
        balances[msg.sender] += tokens;
        CreatePreSale(msg.sender, tokens);
    }
    
    function endPreSale() public {
        require (msg.sender == contractOwner);
        if (isEnded) revert();
        if (block.number < presaleEndBlock && totalSupply != tokenCap) revert();
        isEnded = true;
        if (!travelAnywhereEthFund.send(this.balance)) revert();
    }
}
