pragma solidity ^0.4.18;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
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

contract BurnableToken is StandardToken {

    event Burn(address indexed burner, uint256 value);

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(uint256 _value) public {
        require(_value > 0);
        require(_value <= balances[msg.sender]);
        // no need to require value <= totalSupply, since that would imply the
        // sender's balance is greater than the totalSupply, which *should* be an assertion failure

        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }
}

contract BeeToken is StandardToken, BurnableToken, Ownable {
    // Note: Token Offering == Initial Coin Offering(ICO)
    // Constants
    string public constant symbol = "BEE";
    string public constant name = "Bee Token";
    uint8 public constant decimals = 18;
    uint public constant DECIMAL_MULTIPLIER = 10 ** uint(decimals);
    uint256 public constant INITIAL_SUPPLY = 500000000 * DECIMAL_MULTIPLIER;
    uint256 public constant TOKEN_OFFERING_ALLOWANCE = 150000000 * DECIMAL_MULTIPLIER; // Currently 30%
    uint256 public constant ADMIN_ALLOWANCE = 450000000 * DECIMAL_MULTIPLIER; // 70%
    
    
    uint256 public adminAllowance;          // Number of tokens
    uint256 public tokenOfferingAllowance;  // Number of tokens
    address public adminAddr;               // Address of token admin
    address public tokenOfferingAddr;       // Address of token offering
    bool    public transferEnabled = false; // Enable transfers after conclusion of token offering
    
    modifier onlyWhenTransferEnabled() {
        if (!transferEnabled) {
            require(msg.sender == adminAddr || msg.sender == tokenOfferingAddr);
        }
        _;
    }

    modifier validDestination(address _to) {
        require(_to != address(0x0));
        require(_to != address(this));
        require(_to != owner);
        require(_to != address(adminAddr));
        require(_to != address(tokenOfferingAddr));
        _;
    }
    
    function BeeToken(address _admin) public {
        
        totalSupply = INITIAL_SUPPLY;
        tokenOfferingAllowance = TOKEN_OFFERING_ALLOWANCE;
        adminAllowance = ADMIN_ALLOWANCE;


        balances[msg.sender] = totalSupply;               // Mint tokens
        Transfer(address(0x0), msg.sender, totalSupply);

        adminAddr = _admin;
        approve(adminAddr, adminAllowance);
    }

    function setTokenOffering(address _tokenOfferingAddr, uint256 _amountForSale) external onlyOwner {
        require(!transferEnabled);
        require(_amountForSale <= tokenOfferingAllowance);

        uint amount = (_amountForSale == 0) ? tokenOfferingAllowance : _amountForSale;

        // Clear allowance of old, and set allowance of new
        approve(tokenOfferingAddr, 0);
        approve(_tokenOfferingAddr, amount);

        tokenOfferingAddr = _tokenOfferingAddr;
    }
    
    function enableTransfer() external onlyOwner {
        transferEnabled = true;
        approve(tokenOfferingAddr, 0);
        approve(adminAddr, 0);
        tokenOfferingAllowance = 0;
        adminAllowance = 0;
    }

    function transfer(address _to, uint256 _value) public onlyWhenTransferEnabled validDestination(_to) returns (bool) {
        return super.transfer(_to, _value);
    }
    
    function transferFrom(address _from, address _to, uint256 _value) 
    public onlyWhenTransferEnabled validDestination(_to) returns (bool) {
        bool result = super.transferFrom(_from, _to, _value);
        if (result) {
            if (msg.sender == tokenOfferingAddr)
                tokenOfferingAllowance = tokenOfferingAllowance.sub(_value);
            if (msg.sender == adminAddr)
                adminAllowance = adminAllowance.sub(_value);
        }
        return result;
    }
    
    function burn(uint256 _value) public {
        require(transferEnabled || msg.sender == owner);
        require(balances[msg.sender] >= _value);
        super.burn(_value);
        Transfer(msg.sender, address(0x0), _value);
    }
}


contract BeeTokenOffering is Pausable {


    using SafeMath for uint256;
    using SafeMath for uint;

    uint public constant GAS_LIMIT_IN_WEI = 50000000000 wei;

    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;
    uint public tokensForSale;
    uint public tokenMultiplier;
    bool public fundingCapReached = false;
    bool public saleClosed = false;

    // Participants may clain tokens 7 days after purchase
    uint public constant CLAIM_DELAY = 7 days;

    // Address where funds are collected
    address public beneficiary;

    // Token to be sold
    //address public constant token = tokenContract();
    BeeToken public token;

    // Tokens per ether
    // 2000 Bee($0.20) to Eth($400) => rate = 2000 ~ Update at time of offering
    uint256 public rate;

    // Base cap for contributions in Eth
    uint256 public base;

    // Amount of raised in wei (10**18)
    uint256 public weiRaised;
    // Amount in wei claimed by beneficiary
    uint256 public fundsClaimed;

    // Replace with real start and end times based off of strategy document
    uint256 public doubleTime;
    uint256 public uncappedTime;

    // Contribution limits in Eth per tier
    uint public aAmount;
    uint public bAmount;
    uint public cAmount;
    uint public dAmount;

    // Funding cap in ETH. Change to equal $15M at time of token offering
    uint public constant FUNDING_ETH_HARD_CAP = 37500 * 1 ether;
    // Reserve fund subject to change

    Stages public stage;

    enum Stages { 
        Setup,
        OfferingStarted,
        OfferingEnded,
        Distributed
    }

    // Event for token purchase logging
    // Purchaser - who paid for the tokens
    // Beneficiary - reviever of ether
    // Value - weis paid for purchase
    // Amount - amount of tokens purchased
    event TokenPurchase(
        address indexed purchaser, 
        address indexed _beneficiary, 
        uint256 value, uint256 amount
    );

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    modifier aLister {
        require(whitelistA[msg.sender]);
        _;
    }

    modifier bLister {
        require(whitelistB[msg.sender]);
        _;
    }

    modifier cLister {
        require(whitelistC[msg.sender]);
        _;
    }

    modifier dLister {
        require(whitelistD[msg.sender]);
        _;
    }

    //mapping(address => bool) public registered;
    // Feed whitelist with registered users
    mapping(address => bool) public whitelistA;
    mapping(address => bool) public whitelistB;
    mapping(address => bool) public whitelistC;
    mapping(address => bool) public whitelistD;
    mapping(address => uint) public contributions;

    function BeeTokenOffering(
        uint256 _rate, 
        address _beneficiary, 
        uint256 _base,
        address tokenAddress) public {

        require(_rate > 0);
        require(_beneficiary != address(0));

        require(tokenAddress != address(0));
        token = BeeToken(tokenAddress);

        tokensForSale = token.balanceOf(address(this));

        // Set the number of the token multiplier for its decimals
        tokenMultiplier = 10 ** uint(token.decimals());

        base = _base * (10 ** 17); // convert from Eth to wei*10
        aAmount = base * 30; // Allotted amount per tier in wei
        bAmount = base * 20;
        cAmount = base * 15;
        dAmount = base * 10;
        rate = _rate; // BEE to Ether
        beneficiary = _beneficiary;
        stage = Stages.Setup;
        // Add event for convenience
    }

    // Fallback function can not be used to buy tokens
    function () public payable {
        buy();
    }

    function ownerSafeWithdrawal() external onlyOwner {
        uint balanceToSend = this.balance;
        beneficiary.transfer(balanceToSend);
    }

    // Assign new user tiers
    function whitelistTierA (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelistA[i] = true;
        }
    }

    function whitelistTierB (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelistB[i] = true;
        }
    }

    function whitelistTierC (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelistC[i] = true;
        }
    }

    function whitelistTierD (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelistD[i] = true;
        }
    }

    function startOffering() public onlyOwner atStage(Stages.Setup) {
        stage = Stages.OfferingStarted;
        startTime = now;
        doubleTime = startTime + 48 hours;
        uncappedTime = startTime + 96 hours;
        // Add event for convenience
    }

    // Owner can terminate token offering after it begins
    function endOffering() public onlyOwner atStage(Stages.OfferingStarted) {
        endTime = now;
        stage = Stages.OfferingEnded;
        // Add event for convenience
    }
    
    function buyTokensAList() public payable aLister atStage(Stages.OfferingStarted) {
        address participant = msg.sender;
        require(participant != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);

        if (now < doubleTime) {
            require(contributions[participant] < aAmount);
        } else if (now < uncappedTime) {
            require(contributions[participant] < aAmount*2);
        } else {
            require(contributions[participant] < 30000 * tokenMultiplier);
        }
        contributions[participant] = contributions[participant].add(weiAmount);
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
    }
    
    function buyTokensBList() public payable bLister atStage(Stages.OfferingStarted) {
        address participant = msg.sender;
        require(participant != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);

        if (now < doubleTime) {
            require(contributions[participant] < bAmount);
        } else if (now < uncappedTime) {
            require(contributions[participant] < bAmount*2);
        } else {
            require(contributions[participant] < 30000 * tokenMultiplier);
        }
        contributions[participant] = contributions[participant].add(weiAmount);
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
    }
            
    function buyTokensCList() public payable cLister atStage(Stages.OfferingStarted) {
        address participant = msg.sender;
        require(participant != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);

        if (now < doubleTime) {
            require(contributions[participant] < cAmount);
        } else if (now < uncappedTime) {
            require(contributions[participant] < cAmount*2);
        } else {
            require(contributions[participant] < 30000 * tokenMultiplier);
        }
        contributions[participant] = contributions[participant].add(weiAmount);
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
    }

    function buyTokensDList() public payable dLister atStage(Stages.OfferingStarted) {
        address participant = msg.sender;
        require(participant != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);

        if (now < doubleTime) {
            require(contributions[participant] < dAmount);
        } else if (now < uncappedTime) {
            require(contributions[participant] < dAmount*2);
        } else {
            require(contributions[participant] < 30000 * tokenMultiplier);
        }
        contributions[participant] = contributions[participant].add(weiAmount);
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
    }

    function buy() public payable atStage(Stages.OfferingStarted) {
        if (whitelistA[msg.sender]) {
            buyTokensAList();
        } else if (whitelistB[msg.sender]) {
            buyTokensBList();
        } else if (whitelistC[msg.sender]) {
            buyTokensCList();
        } else if (whitelistD[msg.sender]) {
            buyTokensDList();
        } else {
            revert();
        }
    }

    function allocateTokens(address _to, uint amountWei, uint amountAttoBee) public atStage(Stages.OfferingEnded)
            onlyOwner
    {
        weiRaised = weiRaised.add(amountWei);
        require(weiRaised <= FUNDING_ETH_HARD_CAP);

        contributions[_to] = contributions[_to].add(amountWei);

        if (!token.transferFrom(token.owner(), _to, amountAttoBee)) {
            revert();
        }

        updateFundingCap();
    }

    // Return true if ico event has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    function updateFundingCap() internal {
        assert(weiRaised <= FUNDING_ETH_HARD_CAP);
        if (weiRaised == FUNDING_ETH_HARD_CAP) {
            // Check if the funding cap has been reached
            fundingCapReached = true;
            saleClosed = true;
        }
    }

    // Return true if the transaction can buy tokens
    function validPurchase() internal view returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool withinFunding = weiRaised <= FUNDING_ETH_HARD_CAP;  
        return withinPeriod && nonZeroPurchase && withinFunding;
    }

}
