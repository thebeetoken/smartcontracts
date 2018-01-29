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

    // Price of the tokens as in tokens per ether
    uint256 public rate;

    // Amount of raised in Wei (1 ether)
    uint256 public weiRaised;

    // Timelines for different contribution limit policy
    uint256 public capDoublingTimestamp;
    uint256 public capReleaseTimestamp;

    // Individual contribution limits in Wei per tier
    uint256[3] public tierCaps;

    // Whitelists of participant address for each tier
    mapping(uint8 => mapping(address => bool)) public whitelists;

    // Contributions in Wei for each participant
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

    event OfferingOpens(uint256 startTime, uint256 endTime);
    event OfferingCloses(uint256 endTime, uint256 totalWeiRaised);
    /**
     * Event for token purchase logging
     *
     * @param purchaser Who paid for the tokens
     * @param value Weis paid for purchase
     * @return amount Amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);

    event WhitelistUser(uint8 tier, address indexed user);

    /**
     * Modifier that requires certain stage before executing the main function body
     *
     * @param expectedStage Value that the current stage is required to match
     */
    modifier atStage(Stages expectedStage) {
        require(stage == expectedStage);
        _;
    }

    /**
     * Modifier that validates a purchase at a tier
     * All the following has to be met:
     * - current time within the offering period
     * - valid sender address and ether value greater than 0.1
     * - total Wei raised not greater than FUNDING_ETH_HARD_CAP
     * - contribution per perticipant within contribution limit
     *
     * @param tier Index of the tier
     */
    modifier validPurchase(uint8 tier) {
        require(tier < tierCaps.length);
        require(now >= startTime && now <= endTime && stage == Stages.OfferingStarted);

        uint256 contributionInWei = msg.value;
        address participant = msg.sender;
        require(participant != address(0) && contributionInWei > 100000000000000000);
        require(weiRaised.add(contributionInWei) <= FUNDING_ETH_HARD_CAP);

        uint256 initialCapInWei = tierCaps[tier];
        
        if (now < capDoublingTimestamp) {
            require(contributions[participant].add(contributionInWei) <= initialCapInWei);
        } else if (now < capReleaseTimestamp) {
            require(contributions[participant].add(contributionInWei) <= initialCapInWei.mul(2));
        }

        _;
    }

    /**
     * The constructor of the contract.
     * Note: tierCaps[tier] define the individual contribution limits in Wei of each address
     * per tier within the first tranche of the sale (sale start ~ capDoublingTimestamp)
     * these limits are doubled between capDoublingTimestamp ~ capReleaseTimestamp
     * and are lifted completely between capReleaseTimestamp ~ end time
     *  
     * @param beeToEtherRate Number of beetokens per ether
     * @param beneficiaryAddr Address where funds are collected
     * @param baseContributionCapInWei Base contribution limit in Wei per address
     */
    function BeeTokenOffering(
        uint256 beeToEtherRate, 
        address beneficiaryAddr, 
        uint256 baseContributionCapInWei,
        address tokenAddress
    ) public {
        require(beeToEtherRate > 0);
        require(beneficiaryAddr != address(0));
        require(tokenAddress != address(0));

        token = BeeToken(tokenAddress);
        rate = beeToEtherRate;
        beneficiary = beneficiaryAddr;
        stage = Stages.Setup;

        // Contribution cap per tier in Wei
        tierCaps[0] = baseContributionCapInWei.mul(3);
        tierCaps[1] = baseContributionCapInWei.mul(2);
        tierCaps[2] = baseContributionCapInWei;
    }

    /**
     * Fallback function can be used to buy tokens
     */
    function () public payable {
        buy();
    }

    /**
     * Withdraw available ethers into beneficiary account, serves as a safety, should never be needed
     */
    function ownerSafeWithdrawal() external onlyOwner {
        beneficiary.transfer(this.balance);
    }

    function updateRate(uint256 beeToEtherRate) public onlyOwner atStage(Stages.Setup) {
        rate = beeToEtherRate;
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
            WhitelistUser(tier, users[i]);
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
        endTime = capReleaseTimestamp.add(durationInSeconds);
        OfferingOpens(startTime, endTime);
    }

    /**
     * End the offering
     */
    function endOffering() public onlyOwner atStage(Stages.OfferingStarted) {
        endOfferingImpl();
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
        return now > endTime || stage == Stages.OfferingEnded;
    }

    /**
     * Internal function that buys token per tier
     * 
     * Investiment limit changes over time:
     * 1) [offering starts ~ capDoublingTimestamp]:     1x of contribution limit per tier (1 * tierCaps[tier])
     * 2) [capDoublingTimestamp ~ capReleaseTimestamp]: limit per participant is raised to 2x of contribution limit per tier (2 * tierCaps[tier])
     * 3) [capReleaseTimestamp ~ offering ends]:        no limit per participant as along as total Wei raised is within FUNDING_ETH_HARD_CAP
     *
     * @param tier Index of tier of whitelisted participant
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
            endOfferingImpl();
        }
        
        // Transfer funds to beneficiary
        beneficiary.transfer(contributionInWei);
        TokenPurchase(msg.sender, contributionInWei, tokens);       
    }

    /**
     * End token offering by set the stage and endTime
     */
    function endOfferingImpl() internal {
        endTime = now;
        stage = Stages.OfferingEnded;
        OfferingCloses(endTime, weiRaised);
    }

    /**
     * Allocate tokens for presale participants before public offering, can only be executed at Stages.Setup stage.
     *
     * @param to Participant address to send beetokens to
     * @param tokens Amount of beetokens to be sent to parcitipant 
     */
    function allocateTokensBeforeOffering(address to, uint256 tokens)
        public
        onlyOwner
        atStage(Stages.Setup)
        returns (bool)
    {
        if (!token.transferFrom(token.owner(), to, tokens)) {
            revert();
        }
        return true;
    }
    
    /**
     * Bulk version of allocateTokensBeforeOffering
     */
    function batchAllocateTokensBeforeOffering(address[] toList, uint256[] tokensList)
        external
        onlyOwner
        atStage(Stages.Setup)
        returns (bool)
    {
        require(toList.length == tokensList.length);

        for (uint32 i = 0; i < toList.length; i++) {
            allocateTokensBeforeOffering(toList[i], tokensList[i]);
        }
        return true;
    }

}
