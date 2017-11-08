pragma solidity ^0.4.16;


/**
 * Math operations with safety checks
 */
library SafeMath {
    
    
    function safeMul(uint256 a, uint256 b) internal returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint256 a, uint256 b) internal returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function safeSub(uint256 a, uint256 b) internal returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint256 a, uint256 b) internal returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


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


interface Token {
    function transfer(address receiver, uint amount) returns (bool success);
    function balanceOf(address _owner) constant returns (uint256 balance);
}


contract BeeTokenOffering is Ownable {

    
    using SafeMath for uint256;
    using SafeMath for uint;


    // Start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // Address where funds are collected
    address public wallet;

    // Token to be sold
    //address public constant token = tokenContract();
    Token public tokenContract;

    // How many token units a buyer gets per wei
    uint256 public rate;

    // Base amount of tokens allowed for purchase*10^(-17)
    uint256 public base;

    // Amount of raised in wei (10**18)
    uint256 public weiRaised;


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


    // Event for token purchase logging
    // Purchaser - who paid for the tokens
    // Beneficiary - who got the tokens
    // Value - weis paid for purchase
    // Amount - amount of tokens purchased
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    mapping(address => bool) registered;
    // Feed whiteList with registered users
    mapping(address => uint) whiteList;
    
    
    function BeeTokenOffering(
        uint256 _startTime, 
        uint256 _endTime, 
        uint256 _rate, 
        address _wallet, 
        uint256 _base) public {
            
        require( _startTime >= now);
        require(_endTime >= _startTime);
        require(_rate > 0);
        require(_wallet != 0x0);


        base = _base;
        aAmount = base*30;
        bAmount = base*20;
        cAmount = base*15;
        dAmount = base*10;
        tokenContract = Token(0xb178A41C3908D01B605e2e7Bf9C55da97FD50e94);
        startTime = _startTime;
        endTime = _endTime;
        doubleTime = startTime + 5 minutes;
        uncappedTime = startTime + 10 minutes;
        rate = _rate; // Wei to Bee
        wallet = _wallet;
        tokenContract.transfer(wallet,250000000);
    }

    // Fallback function can be used to buy tokens
    function () public payable {
        buyTokens(msg.sender);
    }

    // Add new registered users
    function registerUser (address user) public onlyOwner {
        registered[user] = true;
    }
    
    // Assign new user tiers
    function whiteListTierA (address user) public onlyOwner {
        whiteList[user] = 0;    
    }
    
    function whiteListTierB (address user) public onlyOwner {
        whiteList[user] = 1;    
    }
    
    function whiteListTierC (address user) public onlyOwner {
        whiteList[user] = 2;    
    }
    
    function whiteListTierD (address user) public onlyOwner {
        whiteList[user] = 3;    
    }


    // Cyclomatic complexity 11, but allowed no more than 7. Change this
    // Low level token purchase function
    function buyTokens(address participant) public payable {
        require(participant != 0x0);
        require(validPurchase());
        require(registered[participant]);

        uint256 weiAmount = msg.value;

        // Calculate token amount to be distributed
        uint256 tokens = weiAmount.safeMul(rate);


        if (now < doubleTime) { 
            if (whiteList[participant] == 0) {
                require(tokenContract.balanceOf(address(participant)) < aAmount);
            } else if (whiteList[participant] == 1) {
                require(tokenContract.balanceOf(participant) < bAmount);
            } else if (whiteList[participant] == 2) {
                require(tokenContract.balanceOf(participant) < cAmount);
            } else if (whiteList[participant] == 3) {
                require(tokenContract.balanceOf(participant) < bAmount);
            }

        } else if (now < uncappedTime) {
            if (whiteList[participant] == 0) {
                require(tokenContract.balanceOf(participant) < aAmount*2);
            } else if (whiteList[participant] == 1) {
                require(tokenContract.balanceOf(participant) < bAmount*2);
            } else if (whiteList[participant] == 2) {
                require(tokenContract.balanceOf(participant) < cAmount*2);
            } else if (whiteList[participant] == 3) {
                require(tokenContract.balanceOf(participant) < bAmount*2);
            }

        } else {
            require(tokenContract.balanceOf(participant) < 3000000000000000000000000);
        }

        // Update state
        weiRaised = weiRaised.safeAdd(weiAmount);

        TokenPurchase(msg.sender, participant, weiAmount, tokens);

        forwardFunds();
    }

    // Return true if ico event has ended
    function hasEnded() public constant returns (bool) {
        return now > endTime;
    }

    // Send ether to the fund collection wallet
    // Override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // Return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool withinFunding = weiRaised <=  FUNDING_ETH_HARD_CAP;  
        return withinPeriod && nonZeroPurchase && withinFunding;
    }

}
