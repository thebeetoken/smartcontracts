pragma solidity ^0.4.16;
import "./BeeToken.sol";


// Ownable contract has an owner address, and provides basic authorization control functions.
contract Ownable {


    address public owner;

    // Ownable constructor sets the original `owner` of the contract to the sender
    function Ownable() public {
        owner = msg.sender;
    }

    // Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Allows the current owner to transfer control of the contract to a newOwner.
    // NewOwner is the address to transfer ownership.
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));      
        owner = newOwner;
    }

}


contract BeeTokenOffering is Ownable {

    
    using SafeMath for uint256;
    using SafeMath for uint;


    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;
    uint public tokensForSale;
    uint public tokenMultiplier;
    
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
    uint public constant FUNDING_ETH_HARD_CAP = 50000;
    // 1875 Bee($0.16) to Eth($300) => rate = 1875
    
    Stages public stage;
    
    enum Stages { 
        OfferingDeployed,
        FinishSetup,
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

    //mapping (address => uint) public 
    //mapping(address => bool) public registered;
    // Feed whiteList with registered users
    mapping(address => uint8) public whitelist;
    mapping(address => uint) public contributions;
    
    function BeeTokenOffering(
        address tokenAddress,
        uint256 _rate, 
        address _beneficiary, 
        uint256 _base) public {
        
        require(_rate > 0);
        require(_beneficiary != address(0));


        base = _base * (10**17); // convert from BEE to attoBEE*10
        aAmount = base*30; // Allotted amount per tier in attoBEE
        bAmount = base*20;
        cAmount = base*15;
        dAmount = base*10;
        token = BeeToken(tokenAddress);
        rate = _rate; // BEE to Ether
        beneficiary = _beneficiary;
        stage = Stages.OfferingDeployed;
        token.transfer(beneficiary, 250000000*(10**18));
        // Add event for convenience
    }

    // Fallback function can be used to buy tokens
    function () public payable atStage(Stages.OfferingStarted) {
        buyTokensAList(msg.sender);
        buyTokensBList(msg.sender);
        buyTokensCList(msg.sender);
        buyTokensDList(msg.sender);
    }

    function ownerSafeWithdrawal() external onlyOwner {
        uint balanceToSend = this.balance;
        beneficiary.transfer(balanceToSend);
    }
    // Do we need to register users before whitelisting? 
    // Add new registered users
    //function registerUser (address[] users) public onlyOwner {
    //    for (uint i = 0; i < users.length; i++) {
    //        registered[users] = true;
    //}
    
    function setup(address tokenAddress) public onlyOwner atStage(Stages.OfferingDeployed) {
        require(tokenAddress != address(0));
        token = BeeToken(tokenAddress);

        tokensForSale = token.balanceOf(address(this));

        // Set the number of the token multiplier for its decimals
        tokenMultiplier = 10 ** uint(token.DECIMALS());

        stage = Stages.FinishSetup;
        // add event for convenience
    }            
    
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
    
    function startOffering() public onlyOwner atStage(Stages.FinishSetup) {
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
    
    function buyTokensAList(address participant) public payable aLister {
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
            require(token.balanceOf(participant) < 3000000000000000000000000);
        }
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
        forwardFunds();
    }
    
    function buyTokensBList(address participant) public payable bLister {
        require(participant != address(0));
        require(validPurchase());
        
        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);
        
        if (now < doubleTime) {
            require(token.balanceOf(address(participant)) < bAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < bAmount*2);
        } else {
            require(token.balanceOf(participant) < 3000000000000000000000000);
        }
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
        forwardFunds();
    }
            
    function buyTokensCList(address participant) public payable cLister {
        require(participant != address(0));
        require(validPurchase());
        
        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);
        
        if (now < doubleTime) {
            require(token.balanceOf(address(participant)) < cAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < cAmount*2);
        } else {
            require(token.balanceOf(participant) < 3000000000000000000000000);
        }
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
        forwardFunds();
    }
            
    function buyTokensDList(address participant) public payable dLister {
        require(participant != address(0));
        require(validPurchase());
        
        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);
        
        if (now < doubleTime) {
            require(token.balanceOf(address(participant)) < dAmount);
        } else if (now < uncappedTime) {
            require(token.balanceOf(participant) < dAmount*2);
        } else {
            require(token.balanceOf(participant) < 3000000000000000000000000);
        }
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
        forwardFunds();
    }
           
    // Need to fix claim and proxyclaim
    function claimTokens() public atStage(Stages.OfferingEnded) returns (bool) {
        return proxyClaimTokens(msg.sender);
    }

    function proxyClaimTokens(address receiverAddress)
        public
        atStage(Stages.OfferingEnded)
        returns (bool)
    {
        require(now > endTime + CLAIM_DELAY);
        require(receiverAddress != address(0));

        if (contributions[receiverAddress] == 0) {
            return false;
        }

        // Number of attoBEE
        uint num = rate * contributions[receiverAddress];

        uint beeTokenOfferingBalance = token.balanceOf(address(this));
        if (num > beeTokenOfferingBalance) {
            num = beeTokenOfferingBalance;
        }

        // Update the total amount of funds for which tokens have been claimed
        fundsClaimed += contributions[receiverAddress];

        // Set receiver bid to 0 before assigning tokens
        contributions[receiverAddress] = 0;

        require(token.transfer(receiverAddress, num));

        // Add event for convenience
        
        // Change stage once all tokens have been distributed
        if (fundsClaimed == weiRaised) {
            stage = Stages.Distributed;
            // add event for convenience
        }

        assert(token.balanceOf(receiverAddress) >= num);
        assert(contributions[receiverAddress] == 0);
        return true;
    }

    // Return true if ico event has ended
    function hasEnded() public constant returns (bool) {
        return now > endTime;
    }

    // Send ether to the fund collection wallet
    function forwardFunds() internal {
        beneficiary.transfer(msg.value);
    }

    // Return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool withinFunding = weiRaised <= FUNDING_ETH_HARD_CAP * 1 ether;  
        return withinPeriod && nonZeroPurchase && withinFunding;
    }

}