pragma solidity ^0.4.18;
import "./BeeToken.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract BeeTokenOffering is Pausable {


    using SafeMath for uint256;

    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // Address where funds are collected
    address public beneficiary;

    // Token to be sold
    BeeToken public token;

    /* 
     * Tokens per ether
     * 2000 Bee($0.20) to Eth($400) => rate = 2000 ~ Update at time of offering
     */ 
    uint256 public rate;

    // Amount of raised in Wei (1 ether)
    uint256 public weiRaised;

    /**
     * Contribution limit at each stage by time:
     * 1) sale start ~ capDoublingTimestamp: 1x of contribution limit per tier (1 * tierCaps[tier])
     * 2) capDoublingTimestamp ~ capReleaseTimestamp: limit per investor is raised to 2x of contribution limit per tier (2 * tierCaps[tier])
     * 3) capReleaseTimestamp ~ sale end: no limit per investor as along as total Wei raised is within FUNDING_ETH_HARD_CAP
     */
    uint256 public capDoublingTimestamp;
    uint256 public capReleaseTimestamp;

    // Contribution limits in Wei per tier
    uint256[3] public tierCaps;

    // whitelist of investor address for each tier
    mapping(uint8 => mapping(address => bool)) public whitelists;

    // contributions in Wei for each investor
    mapping(address => uint256) public contributions;

    // Funding cap in ETH. Change to equal $5M at time of token offering
    uint256 public constant FUNDING_ETH_HARD_CAP = 5000 * 1 ether;
    // Reserve fund subject to change

    Stages public stage;

    enum Stages { 
        Setup,
        OfferingStarted,
        OfferingEnded
    }

    // Event for token purchase logging
    // Purchaser - who paid for the tokens
    // Value - weis paid for purchase
    // Amount - amount of tokens purchased
    event TokenPurchase(
        address indexed purchaser, 
        uint256 value, uint256 amount
    );

    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    function BeeTokenOffering(
        uint256 _rate, 
        address _beneficiary, 
        uint256 _baseCap,
        address tokenAddress) public {

        require(_rate > 0);
        require(_beneficiary != address(0));

        require(tokenAddress != address(0));
        token = BeeToken(tokenAddress);

        // Contribution cap per tier in Wei
        tierCaps[0] = _baseCap.mul(3) * 1 ether;
        tierCaps[1] = _baseCap.mul(2) * 1 ether;
        tierCaps[2] = _baseCap * 1 ether;

        rate = _rate; // BEE to Ether
        beneficiary = _beneficiary;
        stage = Stages.Setup;
        // Add event for convenience
    }

    // Fallback function can be used to buy tokens
    function () public payable {
        buy();
    }

    function ownerSafeWithdrawal() external onlyOwner {
        uint256 balanceToSend = this.balance;
        beneficiary.transfer(balanceToSend);
    }

    // Assign new user tiers
    function whitelist(uint8 tier, address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelists[tier][users[i]] = true;
        }
    }

    function startOffering(uint256 durationInSeconds) public onlyOwner atStage(Stages.Setup) {
        stage = Stages.OfferingStarted;
        startTime = now;
        capDoublingTimestamp = startTime + 24 hours;
        capReleaseTimestamp = startTime + 48 hours;
        endTime = startTime.add(durationInSeconds);
        // Add event for convenience
    }

    // Owner can terminate token offering after it begins
    function endOffering() public onlyOwner atStage(Stages.OfferingStarted) {
        endTime = now;
        stage = Stages.OfferingEnded;
        // Add event for convenience
    }
    
    function buy() public payable whenNotPaused atStage(Stages.OfferingStarted) {
        if (whitelists[0][msg.sender]) {
            buyTokensTier(0);
        } else if (whitelists[1][msg.sender]) {
            buyTokensTier(1);
        } else if (whitelists[2][msg.sender]) {
            buyTokensTier(2);
        } else {
            revert();
        }
    }

    /* INTERNAL FUNCTIONS */

    // Return true if token sale has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    function buyTokensTier(uint8 tier) internal {
        require(tier < tierCaps.length);

        uint256 amount = tierCaps[tier];
        address participant = msg.sender;
        require(participant != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.mul(rate);

        if (now < capDoublingTimestamp) {
            require(contributions[participant] + weiAmount <= amount);
        } else if (now < capReleaseTimestamp) {
            require(contributions[participant] + weiAmount <= amount*2);
        } else {
            require(contributions[participant] + weiAmount <= FUNDING_ETH_HARD_CAP);
        }
        
        weiRaised = weiRaised.add(weiAmount);
        contributions[participant] = contributions[participant].add(weiAmount);

        if (!token.transferFrom(token.owner(), participant, tokens)) {
            revert();
        }
        
        // Transfer funds to beneficiary
        beneficiary.transfer(weiAmount);
        TokenPurchase(msg.sender, weiAmount, tokens);       
        updateFundingCap();
    }

    function updateFundingCap() internal {
        if (weiRaised >= FUNDING_ETH_HARD_CAP) {
            // Check if the funding cap has been reached
            endTime = now;
            stage = Stages.OfferingEnded;
        }
    }

    // Return true if the transaction can buy tokens
    function validPurchase() internal view returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool withinFunding = weiRaised.add(msg.value) <= FUNDING_ETH_HARD_CAP;  
        return withinPeriod && nonZeroPurchase && withinFunding;
    }

    
    // Allocate tokens for presale investors before public offering
    function allocateTokensBeforeOffering(address _to, uint256 amountWei, uint256 amountAttoBee)
        public
        onlyOwner
        atStage(Stages.Setup)
    {
        contributions[_to] = contributions[_to].add(amountWei);

        if (!token.transferFrom(token.owner(), _to, amountAttoBee)) {
            revert();
        }
    }
    
    function allocateTokensArrayBeforeOffering(address[] _to, uint256[] amountWei, uint256[] amountAttoBee)
        external
        onlyOwner
        atStage(Stages.Setup)
    {
        require(_to.length == amountWei.length && _to.length == amountAttoBee.length);

        for (uint32 i = 0; i < _to.length; i++) {
            allocateTokensBeforeOffering(_to[i], amountWei[i], amountAttoBee[i]);
        }
    }

}
