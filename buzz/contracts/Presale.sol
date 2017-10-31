pragma solidity ^0.4.16;

//create presale contract with owner for public presale
//min contribution is 150 ETH ($45000 at today's price)
//add whitelisting logic. i.e. function that accepts account addresses
//in msg from owner
//define min per address, funding hard cap
//set start/end dates
//allow owner to withdraw eth after 3000 eth?
//map address balance 

contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}


contract Presale is Ownable {

    uint256 public constant minAmount = 1 ether;
    uint256 public minAccept = 1 wei;
    uint256 public totalFunds;
    uint256 public presaleStartTime = now;
    uint256 public presaleEndTime = now + 10 minutes;
    uint256 public clawbackTime = now + 30 minutes; // Useful if minAmount not reached

    mapping (address => uint256 ) balanceOf;
    event LogParticipation(address indexed sender, uint256 value, uint256 timestamp);


    event UserList(address indexed sender, uint256 value, uint timestamp);
    
    function sub(uint256 a, uint256 b) internal returns (uint256) {
        require(b <= a);
        return a - b;
    }
    function add(uint256 a, uint256 b) internal returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    
    function Presale() payable {
         //log private presale amounts, add to public
    }
    
    
    function ownerWithdraw(uint256 value) external onlyOwner {
        require(totalFunds > minAmount);
        require(owner.send(value));
    }
    
    mapping(address => bool) whiteList;
    
    function whiteListAddress (address user) onlyOwner {
        whiteList[user] = true;
        
    }
    
    function () payable {
        require(whiteList[msg.sender] == true);
        require(now > presaleStartTime);
        require(now < presaleEndTime);
        require(msg.value >= minAccept);
        //require(msg.value < maxAccpet);
        //require(add(totalFunds, msg.value) < maxAmount);
        addBalance(msg.sender, msg.value);
    }
    
    // Participants can withdraw funds if we do not meet our goals
    function userWithdrawFunds(uint256 value) external {
        // Participant cannot withdraw before the presale ends
        require(now > presaleEndTime);
        // Participant cannot withdraw if the minimum funding amount has been reached
        require(totalFunds < minAmount);
        // Participant can only withdraw an amount up to their contributed balance
        require(balanceOf[msg.sender] < value);
        // Participant's balance is reduced by the claimed amount.
        balanceOf[msg.sender] = sub(balanceOf[msg.sender], value);
        // Send ether back to the participant account
        require(msg.sender.send(value));
    }

    // If funding goals are not reached and Eth remains in the contract for too long
    // Allow owner to withdraw trapped funds
    function ownerClawback() external onlyOwner {
        // The owner cannot withdraw before the clawback date
        require(now > clawbackTime);
        // Send remaining funds back to the owner
        selfdestruct(owner);
    }

    // Keep track of participant contributions and the total funding amount
    function addBalance(address participant, uint256 value) private {
        // Participant's balance is increased by the sent amount
        balanceOf[participant] = add(balanceOf[participant], value);
        // Keep track of the total funding amount
        totalFunds = add(totalFunds, value);
        // Log an event of the participant's contribution
        LogParticipation(participant, value, now);
    }
    

}



