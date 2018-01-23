pragma solidity ^0.4.18;
import "./BeeToken.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract BeeTokenOffering is Pausable {


    using SafeMath for uint256;

    // Start and end timestamps where contributions are allowed (both inclusive)
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
     * 2) capDoublingTimestamp ~ capReleaseTimestamp: limit per participant is raised to 2x of contribution limit per tier (2 * tierCaps[tier])
     * 3) capReleaseTimestamp ~ sale end: no limit per participant as along as total Wei raised is within FUNDING_ETH_HARD_CAP
     */
    uint256 public capDoublingTimestamp;
    uint256 public capReleaseTimestamp;

    // Contribution limits in Wei per tier
    uint256[3] public tierCaps;

    // Whitelists of participant address for each tier
    mapping(uint8 => mapping(address => bool)) public whitelists;

    // contributions in Wei for each participant
    mapping(address => uint256) public contributions;

    // Funding cap in ETH. Change to equal $5M at time of token offering
    uint256 public constant FUNDING_ETH_HARD_CAP = 5000 * 1 ether;

    // The current stage of the offering
    Stages public stage;

    enum Stages { 
        Setup,
        OfferingStarted,
        OfferingEnded
    }

    /**
     * Event for token purchase logging
     *
     * @param purchaser Who paid for the tokens
     * @param value Weis paid for purchase
     * @return amount Amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);

    /**
     * Modifier that requires certain stage before executing the main function body
     *
     * @param _stage Value that the current stage is required to match
     */
    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    /**
     * Modifier that validates a purchase at a tier
     * All the following has to be met:
     * - current time within the offering period
     * - valid sender address and ether value greater than 0
     * - total Wei raised not greater than FUNDING_ETH_HARD_CAP
     * - contribution per perticipant within contribution limit
     *
     * @param tier Index of the tier
     */
    modifier validPurchase(uint8 tier) {
        require(tier < tierCaps.length);
        require(now >= startTime && now <= endTime);
        
        uint256 contributionInWei = msg.value;
        address participant = msg.sender;
        require(participant != address(0) && contributionInWei > 0);
        require(weiRaised.add(contributionInWei) <= FUNDING_ETH_HARD_CAP);  

        uint256 initialCapInWei = tierCaps[tier];
        
        if (now < capDoublingTimestamp) {
            require(contributions[participant] + contributionInWei <= initialCapInWei);
        } else if (now < capReleaseTimestamp) {
            require(contributions[participant] + contributionInWei <= initialCapInWei * 2);
        } else {
            require(contributions[participant] + contributionInWei <= FUNDING_ETH_HARD_CAP);
        }

        _;
    }

    /**
     * The constructor of the contract.
     * TODO: explanation of cap per tier is defined
     *
     * @param _rate Number of beetokens per ether
     * @param _beneficiary Address where funds are collected
     * @param _baseCap Base contribution limit in ether per address
     */
    function BeeTokenOffering(
        uint256 _rate, 
        address _beneficiary, 
        uint256 _baseCap,
        address tokenAddress
    ) public {
        require(_rate > 0);
        require(_beneficiary != address(0));
        require(tokenAddress != address(0));

        token = BeeToken(tokenAddress);
        rate = _rate;
        beneficiary = _beneficiary;
        stage = Stages.Setup;

        // Contribution cap per tier in Wei
        tierCaps[0] = _baseCap.mul(3) * 1 ether;
        tierCaps[1] = _baseCap.mul(2) * 1 ether;
        tierCaps[2] = _baseCap * 1 ether;
    }

    /**
     * Fallback function can be used to buy tokens
     */
    function () public payable {
        buy();
    }

    /**
     * Withdraw available ethers into beneficiary account
     */
    function ownerSafeWithdrawal() external onlyOwner {
        beneficiary.transfer(this.balance);
    }

    /**
     * Whitelist participant address per tier
     * 
     * @param tier Index of tier, should be less than tierCaps.length
     * @param users Array of addresses to be whitelisted
     */
    function whitelist(uint8 tier, address[] users) public onlyOwner {
        require(tier < tierCaps.length);
        for (uint32 i = 0; i < users.length; i++) {
            whitelists[tier][users[i]] = true;
        }
    }

    /**
     * Start the offering
     *
     * @param durationInSeconds Extra duration of the offering on top of the minimum 48 hours
     */
    function startOffering(uint256 durationInSeconds) public onlyOwner atStage(Stages.Setup) {
        stage = Stages.OfferingStarted;
        startTime = now;
        capDoublingTimestamp = startTime + 24 hours;
        capReleaseTimestamp = startTime + 48 hours;
        endTime = startTime.add(durationInSeconds);
    }

    /**
     * End the offering
     */
    function endOffering() public onlyOwner atStage(Stages.OfferingStarted) {
        endTime = now;
        stage = Stages.OfferingEnded;
    }
    
    /**
     * Function to invest ether to buy tokens, can be called directly or called by the fallback function
     * Only whitelisted users can buy tokens.
     *
     * @return bool Return true if purchase succeeds, false otherwise
     */
    function buy() public payable whenNotPaused atStage(Stages.OfferingStarted) returns (bool) {
        for (uint8 i = 0; i < tierCaps.length; ++i) {
            if (whitelists[i][msg.sender]) {
                buyTokensTier(i);
                return true;
            }
        }
        revert();
    }

    /**
     * Function that returns whether offering has ended
     * 
     * @return bool Return true if token offering has ended
     */
    function hasEnded() public view returns (bool) {
        return now > endTime && stage != Stages.OfferingEnded;
    }

    /**
     * Internal function that buys token per tier
     * 
     * Investiment limit changes over time:
     * 1) [offering starts ~ capDoublingTimestamp]:     1x of contribution limit per tier (1 * tierCaps[tier])
     * 2) [capDoublingTimestamp ~ capReleaseTimestamp]: limit per participant is raised to 2x of contribution limit per tier (2 * tierCaps[tier])
     * 3) [capReleaseTimestamp ~ offering ends]:        no limit per participant as along as total Wei raised is within FUNDING_ETH_HARD_CAP
     *
     * @param tier Num of tier to buy tokens in
     */
    function buyTokensTier(uint8 tier) internal validPurchase(tier) {
        address participant = msg.sender;
        uint256 contributionInWei = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = contributionInWei.mul(rate);
        
        if (!token.transferFrom(token.owner(), participant, tokens)) {
            revert();
        }

        weiRaised = weiRaised.add(contributionInWei);
        contributions[participant] = contributions[participant].add(contributionInWei);
        // Check if the funding cap has been reached, end the offering if so
        if (weiRaised >= FUNDING_ETH_HARD_CAP) {
            endTime = now;
            stage = Stages.OfferingEnded;
        }
        
        // Transfer funds to beneficiary
        beneficiary.transfer(contributionInWei);
        TokenPurchase(msg.sender, contributionInWei, tokens);       
    }
    
    /**
     * Allocate tokens for presale participants before public offering, can only be executed at Stages.Setup stage.
     *
     * @param to Participant address to send beetokens to
     * @param amountWei Contribution in Wei
     * @param amountBeeToSend Amount of beetokens to be sent to parcitipant
     */
    function allocateTokensBeforeOffering(address to, uint256 amountWei, uint256 amountBeeToSend)
        public
        onlyOwner
        atStage(Stages.Setup)
        returns (bool)
    {
        // TODO: add logic to avoid double sending ?
        contributions[to] = contributions[to].add(amountWei);

        if (!token.transferFrom(token.owner(), to, amountBeeToSend)) {
            revert();
        }
        return true;
    }
    
    /**
     * Bulk version of allocateTokensBeforeOffering
     */
    function allocateTokensArrayBeforeOffering(address[] to, uint256[] amountWei, uint256[] amountBeeToSend)
        external
        onlyOwner
        atStage(Stages.Setup)
        returns (bool)
    {
        require(to.length == amountWei.length && to.length == amountBeeToSend.length);

        for (uint32 i = 0; i < to.length; i++) {
            allocateTokensBeforeOffering(to[i], amountWei[i], amountBeeToSend[i]);
        }
        return true;
    }

}
