pragma solidity ^0.4.17;
import "./SafeMath.sol";

// This is our initial ICO template. Still need to add logic to allow transfer to final token.
// Need to make sure people cannot trade token until after sale. 
// 
// Ownable contract has an owner address, and provides basic authorization control functions.
contract Ownable {
    
    
    address public owner;

    // Ownable constructor sets the original `owner` of the contract to the sender
    function Ownable()  public {
        owner = msg.sender;
    }

    // Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Allows the current owner to transfer control of the contract to a newOwner.
    // NewOwner is the address to transfer ownership.
    function transferOwnership(address newOwner) onlyOwner  public {
        require(newOwner != address(0));      
        owner = newOwner;
    }

}


contract ERC20 {
   
    
    // Create supply of ERC20
    uint256 public totalSupply;
    // Checks balance of address
    function balanceOf(address who) constant returns (uint256);
    // Allows for trasfer of token
    function transfer(address from, address to, uint256 value) public;
    // Amount limiter
    function allowance(address owner, address spender) constant returns (uint256);
    // Check if transferrable
    function transferFrom(address from, address to, uint256 value) returns (bool);
    // Confirmation
    function approve(address spender, uint256 value) returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

}

contract BasicToken is ERC20 {
    
    
    using SafeMath for uint256;

    mapping(address => uint) balances;

    // Transfer token for an address
    // _to - revieving address
    // _value - amount to be transferred
    function transfer(address _to, uint256 _value) returns (bool) {
        require(_to != address(0));

        // SafeMath will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    //  Get the balance of the specified address.
    // _owner - account to be queried. 
    // returns uint256 representing the amount owned by the passed address.
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

}


contract StandardToken is ERC20, BasicToken {

    
    mapping (address => mapping (address => uint256)) allowed;

    // Transfer tokens from one address to another
    function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
        require(_to != address(0));

        var _allowance = allowed[_from][msg.sender];

        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // require (_value <= _allowance);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    // _spender - The address which will spend the funds.
    // _value - The amount of tokens to be spent.
    function approve(address _spender, uint256 _value) returns (bool) {

        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    // Function to check the amount of tokens that an owner allowed to a spender.
    // _owner - address The address which owns the funds.
    // _spender - address The address which will spend the funds.
    // returns uint256 specifying the amount of tokens still available for the spender.
    //
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function increaseApproval (address _spender, uint _addedValue) 
    returns (bool success) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) 
    returns (bool success) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

}


contract buzzSale is StandardToken, Ownable {
    
    using SafeMath for uint256;

    // The token being sold
    StandardToken public token;

    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // Address where funds are collected
    address public wallet;

    // How many token units a buyer gets per wei
    uint256 public rate;

    // Amount of raised money in wei
    uint256 public weiRaised;


    // Event for token purchase logging
    // Purchaser - who paid for the tokens
    // Beneficiary - who got the tokens
    // Value - weis paid for purchase
    // Amount - amount of tokens purchased
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


    function buzzSale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet)  public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_rate > 0);
        require(_wallet != 0x0);

        token = createTokenContract();
        startTime = _startTime;
        endTime = _endTime;
        rate = _rate;
        wallet = _wallet;
    }

    // Creates the token to be sold. 
    // Override this method to have presale of a specific mintable token.
    //function createTokenContract() internal returns (MintableToken) {
    //    return new MintableToken();
    //}


    // Fallback function can be used to buy tokens
    function () payable  public {
        buyTokens(msg.sender);
    }

    // Low level token purchase function
    function buyTokens(address beneficiary) payable  public {
        require(beneficiary != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be created
        uint256 tokens = weiAmount.mul(rate);

        // Update state
        weiRaised = weiRaised.add(weiAmount);

        token.mint(beneficiary, tokens);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // Send ether to the fund collection wallet
    // Override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // Return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        return withinPeriod && nonZeroPurchase;
    }

    // Return true if ico event has ended
    function hasEnded() public constant returns (bool) {
        return now > endTime;
    }


}
