pragma solidity ^0.4.18;
import "./BeeToken.sol";
import "./lifecycle/Pausable.sol";


contract BeeTokenOffering is Pausable {

    
    using SafeMath for uint256;
    using SafeMath for uint;
    
    //uint public constant GAS_LIMIT_IN_WEI = 50000000000 wei;

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
    uint256 public rate;

    // Base amount of tokens allowed for purchase*10^(-17)
    uint256 public base;

    // Amount of raised in wei (10**18)
    uint256 public weiRaised;
    uint256 public fundsClaimed;


    // Replace with real start and end times based off of strategy document
    uint256 public doubleTime;
    uint256 public uncappedTime;

    // Input base allowance of tokens 
    uint public aAmount;
    uint public bAmount;
    uint public cAmount;
    uint public dAmount;

    // Funding cap in ETH. Change to equal $15M at time of token offering
    uint public constant FUNDING_ETH_HARD_CAP = 37500 * 1 ether;
    // Reserve fund subject to change
    // 2000 Bee($0.20) to Eth($400) => rate = 2000 ~ Update at time of offering
    
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
        require(whitelist[msg.sender] == 0);
        _;
    }
        
    modifier bLister {
        require(whitelist[msg.sender] == 1);
        _;
    }
    
    modifier cLister {
        require(whitelist[msg.sender] == 2);
        _;
    }
    
    modifier dLister {
        require(whitelist[msg.sender] == 3);
        _;
    }

    //mapping(address => uint) public 
    //mapping(address => bool) public registered;
    // Feed whiteList with registered users
    mapping(address => uint8) public whitelist;
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
        tokenMultiplier = 10 ** uint(token.DECIMALS());

        base = _base * (10 ** 17); // convert from BEE to attoBEE*10
        aAmount = base * 30; // Allotted amount per tier in attoBEE
        bAmount = base * 20;
        cAmount = base * 15;
        dAmount = base * 10;
        rate = _rate; // BEE to Ether
        beneficiary = _beneficiary;
        stage = Stages.Setup;
        // Add event for convenience
    }

    // Fallback function can be used to buy tokens
    function () public payable atStage(Stages.OfferingStarted) {
        buyTokensDList();
    }

    // Do we need to register users before whitelisting? 
    // Add new registered users
    //function registerUser (address[] users) public onlyOwner {
    //    for (uint i = 0; i < users.length; i++) {
    //        registered[users] = true;
    //}
          
    // Assign new user tiers
    function whitelistTierA (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelist[i] = 0;
        }
    }
    
    function whitelistTierB (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelist[i] = 1;
        }
    }
    
    function whitelistTierC (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelist[i] = 2;
        }
    }
    
    function whitelistTierD (address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelist[i] = 3;
        }
    }
    
    function startOffering() public onlyOwner atStage(Stages.Setup) {
        stage = Stages.OfferingStarted;
        startTime = now;
        doubleTime = startTime + 48 hours;
        uncappedTime = startTime + 96 hours;
        // Add event for convenience
    }
    
    
    // Owner can terminate token offering whenever
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
            require(token.balanceOf(address(participant)) < aAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < aAmount*2);
        } else {
            require(token.balanceOf(participant) < 150000000 * tokenMultiplier);
        }
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
            require(token.balanceOf(address(participant)) < bAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < bAmount * 2);
        } else {
            require(token.balanceOf(participant) < 150000000 * tokenMultiplier);
        }
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
            require(token.balanceOf(address(participant)) < cAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < cAmount * 2);
        } else {
            require(token.balanceOf(participant) < 150000000 * tokenMultiplier);
        }
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
            require(token.balanceOf(address(participant)) < dAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < dAmount * 2);
        } else {
            require(token.balanceOf(participant) < 150000000 * tokenMultiplier);
        }
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
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

    function ownerSafeWithdrawal() external onlyOwner {
        uint balanceToSend = this.balance;
        beneficiary.transfer(balanceToSend);
    }
    
    function updateFundingCap() internal {
        assert (weiRaised <= FUNDING_ETH_HARD_CAP);
        if (weiRaised == FUNDING_ETH_HARD_CAP) {
            // Check if the funding cap has been reached
            fundingCapReached = true;
            saleClosed = true;
        }
    }

    // Return true if ico event has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    // Return true if the transaction can buy tokens
    function validPurchase() internal view returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool withinFunding = weiRaised <= FUNDING_ETH_HARD_CAP;  
        return withinPeriod && nonZeroPurchase && withinFunding;
    }

}