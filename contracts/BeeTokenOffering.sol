pragma solidity ^0.4.18;
import "./BeeToken.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract BeeTokenOffering is Pausable {


    using SafeMath for uint256;

    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // Address where funds are collected
    address public beneficiary;

    // Token to be sold
    BeeToken public token;

    // Tokens per ether
    // 2000 Bee($0.20) to Eth($400) => rate = 2000 ~ Update at time of offering
    uint256 public rate;

    // Amount of raised in wei (10**18)
    uint256 public weiRaised;

    // Replace with real start and end times based off of strategy document
    uint256 public capDoublingTimestamp;
    uint256 public capReleaseTimestamp;

    // Contribution limits in Eth per tier
    uint256[2] public tierCaps;

    // Funding cap in ETH. Change to equal $5M at time of token offering
    uint public constant FUNDING_ETH_HARD_CAP = 5000 * 1 ether;
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

    // add msg.sender logic to whitelist user
    modifier belongsToList(uint8 idx) {
        require(whitelists[idx][msg.sender]);
        _;
    }

    mapping(uint8 => mapping(address => bool)) public whitelists;
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

        tierCaps[0] = _baseCap.mul(2); // Contribution cap per tier in ether
        tierCaps[1] = _baseCap;

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
        uint balanceToSend = this.balance;
        beneficiary.transfer(balanceToSend);
    }

    // Assign new user tiers
    function whitelist(uint8 idx, address[] users) public onlyOwner {
        for (uint32 i = 0; i < users.length; i++) {
            whitelists[idx][users[i]] = true;
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
    
    function buyTokensTier0() public payable whenNotPaused belongsToList(0) atStage(Stages.OfferingStarted){
        buyTokensTier(tierCaps[0]);
    }

    function buyTokensTier1() public payable whenNotPaused belongsToList(1) atStage(Stages.OfferingStarted){
        buyTokensTier(tierCaps[1]);
    }


    function buy() public payable whenNotPaused atStage(Stages.OfferingStarted) {
        if (whitelists[0][msg.sender]) {
            buyTokensTier0();
        } else if (whitelists[1][msg.sender]) {
            buyTokensTier1();
        } else {
            revert();
        }
    }

/*
* consider moving logic to another contract
    function allocateTokens(address _to, uint256 amountWei, uint256 amountAttoBee)
        public
        onlyOwner
    {
        weiRaised = weiRaised.add(amountWei);

        contributions[_to] = contributions[_to].add(amountWei);

        if (!token.transferFrom(token.owner(), _to, amountAttoBee)) {
            revert();
        }

        updateFundingCap();
    }
    
    function allocateTokensArray(address[] _to, uint256[] amountWei, uint256[] amountAttoBee)
        external
        onlyOwner
    {
        require(_to.length == amountWei.length);
        require(_to.length == amountAttoBee.length);
        for (uint32 i = 0; i < _to.length; i++) {
            allocateTokens(_to[i], amountWei[i], amountAttoBee[i]);
        }
    }
*/
    
    // Return true if token sale has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }
    
    function buyTokensTier(uint256 amount) internal {
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

}
