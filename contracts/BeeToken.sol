pragma solidity ^0.4.18; 
import "./SafeMath.sol";


contract ERC20 {

    // Create supply of ERC20
    uint256 public totalSupply;
    // Checks balance of address
    function balanceOf(address who) public constant returns (uint256);
    // Allows for trasfer of token
    function transfer(address from, address to, uint256 value) public;
    // Amount limiter
    function allowance(address owner, address spender) public constant returns (uint256);
    // Check if transferrable
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    // Confirmation
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

}


contract BasicToken is ERC20 {


    using SafeMath for uint256;

    mapping(address => uint) public balances;

    // Transfer token for an address
    // _to - revieving address
    // _value - amount to be transferred
    function transfer(address _to, uint256 _value) public returns (bool) {
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
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }

}


contract StandardToken is ERC20, BasicToken {


    mapping (address => mapping (address => uint256)) public allowed;

    // Transfer tokens from one address to another
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
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
    function approve(address _spender, uint256 _value) public returns (bool) {

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
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function increaseApproval (address _spender, uint _addedValue) 
    public returns (bool success) 
    {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) 
    public returns (bool success) 
    {
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


contract BeeToken is StandardToken {

    
    string public constant SYMBOL = "BEE";
    string public constant NAME = "Bee Token";
    uint8 public constant DECIMALS = 18;
    uint public constant DECIMAL_MULTIPLIER = 10 ** uint(DECIMALS);
    uint256 public constant TOTAL_SUPPLY = 500000000 * DECIMAL_MULTIPLIER;
    uint256 public walletSupply;
    uint256 public tokenOfferingSupply;
    
    event Deployed(uint indexed totalSupply);
    event Burned(
        address indexed _reciever,
        uint indexed _num,
        uint indexed totalSupply
        );
    
    
    function BeeToken(
        address tokenOfferingAddress,
        address walletAddress,
        uint256 tokensAvailableAfterPresale)
        public 
    {
        require(tokenOfferingAddress != address(0));
        require(walletAddress != address(0));
        totalSupply = TOTAL_SUPPLY;
        tokenOfferingSupply = 150000000 - totalSupply.sub(tokensAvailableAfterPresale);
        walletSupply = totalSupply - tokenOfferingSupply;
        // Changed to 30% offered during presale and token offering
        balances[tokenOfferingAddress] = tokenOfferingSupply * DECIMAL_MULTIPLIER;
        balances[walletAddress] =  walletSupply * DECIMAL_MULTIPLIER;
        
        Transfer(address(0), tokenOfferingAddress, balances[tokenOfferingAddress]);
        Transfer(address(0), walletAddress, balances[walletAddress]);
        
        Deployed(totalSupply);
        
        assert(totalSupply == balances[tokenOfferingAddress] + balances[walletAddress]);
    }
    
    
    function burn(uint num) public {
        require(num < 0);
        require(balances[msg.sender] >= num);
        require(totalSupply >= num);
        
        uint balance = balances[msg.sender];
        
        balances[msg.sender] -= num;
        totalSupply -= num;
        Burned(msg.sender, num, totalSupply);
        Transfer(msg.sender, address(0), num);
        
        assert(balances[msg.sender] == balance - num);
    }
    
}