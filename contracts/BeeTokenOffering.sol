pragma solidity ^0.4.18;
import "./BeeToken.sol";
import "./lifecycle/Pausable.sol";


contract BeeTokenOffering is Pausable {


    using SafeMath for uint256;
    using SafeMath for uint;

    uint public constant GAS_LIMIT_IN_WEI = 50000000000 wei;
    //bool private rentrancy_lock = false; Need if we send tokens with buy orders


    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;
    uint public tokensForSale;
    uint public tokenMultiplier;
    bool public fundingCapReached = false;
    bool public saleClosed = false;

    // Participants may claim tokens 7 days after purchase
    uint public constant CLAIM_DELAY = 7 days;

    // Address where funds are collected
    address public beneficiary;

    // Token to be sold
    //address public constant token = tokenContract();
    BeeToken public token;

    // Tokens per ether
    // 2000 Bee($0.20) to Eth($400) => rate = 2000 ~ Update at time of offering
    uint256 public rate;

    // base cap for contributions in Eth
    uint256 public baseCap;

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
    
    // Recursive call protection (not necessary if using claim delay)
    /*modifier nonReentrant() {
        require(!rentrancy_lock);
        rentrancy_lock = true;
        _;
        rentrancy_lock = false;
    }*/

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
        uint256 _baseCap,
        address tokenAddress) public {

        require(_rate > 0);
        require(_beneficiary != address(0));

        require(tokenAddress != address(0));
        token = BeeToken(tokenAddress);

        tokensForSale = token.balanceOf(address(this));

        // Set the number of the token multiplier for its decimals
        tokenMultiplier = 10 ** uint(token.decimals());

        baseCap = _baseCap * (10 ** 17); // convert from Eth to Decawei
        aAmount = baseCap * 30; // Contribution cap per tier in wei
        bAmount = baseCap * 20;
        cAmount = baseCap * 15;
        dAmount = baseCap * 10;
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
        buyTokensList(aAmount);
    }
    
    function buyTokensBList() public payable bLister atStage(Stages.OfferingStarted) {
        buyTokensList(bAmount);
    }
            
    function buyTokensCList() public payable cLister atStage(Stages.OfferingStarted) {
        buyTokensList(cAmount);
    }

    function buyTokensDList() public payable dLister atStage(Stages.OfferingStarted) {
        buyTokensList(dAmount);
    }
    
    function buyTokensList(uint amount) internal {
        address participant = msg.sender;
        require(participant != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);

        if (now < doubleTime) {
            require(contributions[participant] < amount);
        } else if (now < uncappedTime) {
            require(contributions[participant] < amount*2);
        } else {
            require(contributions[participant] < 30000 * tokenMultiplier);
        }
        contributions[participant] = contributions[participant].add(weiAmount);
        weiRaised = weiRaised.add(weiAmount);
        TokenPurchase(msg.sender, participant, weiAmount, tokens);
    }

    function buy() public payable whenNotPaused atStage(Stages.OfferingStarted) {
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
