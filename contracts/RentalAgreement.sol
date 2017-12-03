pragma solidity ^0.4.16;
// Current iteration accepts Ether as payment using msg.value
// Need to restrict contract to accept specific token contract
// and keep track of price in tokens. Transfer tokens using 
// token contract's transfer function.


contract RentalAgreement {
    
    
    bool internal contractPaid; //replace with state transitions
    address public guestAddress;
    address public hostAddress;
    address public arbiter; //sent to this address if bad transaction
    uint public tokensPerNight; //currently in ETH. Change to test token
    uint public guestDeposit;
    uint public hostDeposit;
    uint public paidTime;
    bool internal hostSatisfied = false;
    bool internal guestSatisfied = false;
    //uint public expirationTimestamp;
    string public bookingUUID;
    
    
    //event ContractIsPaid(uint timestamp);
    //event BothSatisfied(bool satisfied);
    //event ContractStart(uint timestamp, string bookingID);
    //event ContractEnded(uint timestamp, string bookingID);
    
    mapping (address => uint) public rentPaid;
    mapping (address => uint) public depositPaid;
    mapping (address => bool) public response;
    
    Stages public stage;
    
    enum Stages {
        Start,
        DepositsPaid,
        GuestPaid,
        Satisfied
    }

    modifier onlyHost() {
        require(msg.sender == hostAddress);
        _;
    }

    modifier onlyGuest() {
        require(msg.sender == guestAddress);
        _;
    }
    
    modifier atStage(Stages _stage) {
        require(stage == _stage);
        _;
    }

    function RentalAgreement (
        address specifiedHost, 
        address specifiedGuest,
        string bookingID, 
        uint rent,
        uint _guestDeposit,
        uint _hostDeposit) public 
        {
            tokensPerNight = rent;
            guestDeposit = _guestDeposit;
            hostDeposit = _hostDeposit;
            hostAddress = specifiedHost;
            guestAddress = specifiedGuest;
            arbiter = msg.sender;
            // Convert date time into unix timestamp
            //expirationTimestamp = expTime;
            bookingUUID = bookingID;
            stage = Stages.Start;
        }
    
    function () public payable { 
        
        revert(); 
    }//return funds minus gased used if wrongly sent
 
    function payDeposit() public payable {
        
        require(msg.sender == hostAddress || msg.sender == guestAddress);
        
        if (msg.sender == guestAddress) {
            depositPaid[guestAddress] += msg.value;
        }else {depositPaid[hostAddress] += msg.value;}
        
        if (depositPaid[hostAddress] >= hostDeposit && depositPaid[guestAddress] >= guestDeposit) {
            stage = Stages.DepositsPaid;
        }
    }  

    function payContract() public payable {
        
        if (msg.sender != guestAddress || contractPaid) { 
            revert();
        }
        rentPaid[guestAddress] += msg.value;
        if (rentPaid[guestAddress] >= tokensPerNight) {
            contractPaid = true;
            paidTime = now;
        }
    }
    
    function satisfied(bool satisfaction) public {
        
        require(msg.sender == hostAddress || msg.sender == guestAddress);
        
        if (msg.sender == hostAddress) {
            hostSatisfied = satisfaction;
            response[msg.sender] = true;
        }else {
            guestSatisfied = satisfaction;
            response[msg.sender] = true;
        }
        if (response[guestAddress] && response[hostAddress]) {
            stage = Stages.Satisfied;
        }
    }

    function payout() public atStage(Stages.Satisfied) {
        
        if (guestSatisfied && hostSatisfied) {
            guestAddress.transfer(depositPaid[guestAddress]);
            hostAddress.transfer(depositPaid[hostAddress]+rentPaid[guestAddress]);
        }else {
            selfdestruct(arbiter);
        }
    }

    function getHostStatus() public view returns (bool ok) {
        return hostSatisfied;
    }

    function getGuestStatus() public view returns (bool ok) {
        return guestSatisfied;
    }
}