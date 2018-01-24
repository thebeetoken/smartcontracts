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
     * Individual contribution limit at each stage by time:
     * 1) sale start ~ capDoublingTimestamp: 1x of contribution limit per tier (1 * tierCaps[tier])
     * 2) capDoublingTimestamp ~ capReleaseTimestamp: limit per participant is raised to 2x of contribution limit per tier (2 * tierCaps[tier])
     * 3) capReleaseTimestamp ~ sale end: no limit per participant as along as total Wei raised is within FUNDING_ETH_HARD_CAP
     */
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
            require(contributions[participant].add(contributionInWei) <= initialCapInWei);
        } else if (now < capReleaseTimestamp) {
            require(contributions[participant].add(contributionInWei) <= initialCapInWei.mul(2));
        } else {
            require(contributions[participant].add(contributionInWei) <= FUNDING_ETH_HARD_CAP);
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
     * @param etherToBeeRate Number of beetokens per ether
     * @param beneficiaryAddr Address where funds are collected
     * @param baseContributionCapInEther Base contribution limit in ether per address
     */
    function BeeTokenOffering(
        uint256 etherToBeeRate, 
        address beneficiaryAddr, 
        uint256 baseContributionCapInEther,
        address tokenAddress
    ) public {
        require(etherToBeeRate > 0);
        require(beneficiaryAddr != address(0));
        require(tokenAddress != address(0));

        token = BeeToken(tokenAddress);
        rate = etherToBeeRate;
        beneficiary = beneficiaryAddr;
        stage = Stages.Setup;

        // Contribution cap per tier in Wei
        tierCaps[0] = baseContributionCapInEther.mul(3) * 1 ether;
        tierCaps[1] = baseContributionCapInEther.mul(2) * 1 ether;
        tierCaps[2] = baseContributionCapInEther * 1 ether;
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
        endTime = capReleaseTimestamp.add(durationInSeconds);
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
    function allocateTokensArrayBeforeOffering(address[] toList, uint256[] tokensList)
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
