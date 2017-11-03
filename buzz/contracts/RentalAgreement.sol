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
    uint public  paidTime;
    bool internal hostSatisfied = false;
    bool internal guestSatisfied = false;
    uint public expirationTimestamp;
    string public bookingUUID;

    event ContractIsPaid(uint timestamp);
    event BothSatisfied(bool satisfied);
    event ContractStart(uint timestamp, string bookingID);
    event ContractEnded(uint timestamp, string bookingID);

    modifier onlyHost() {
        require(msg.sender == hostAddress);
        _;
    }

    modifier onlyGuest() {
        require(msg.sender == guestAddress);
        _;
    }

    //not working as expected. Please change
    //modifier notExpired() {
    //    require(now < expirationTimestamp);
    //    _;
    //}
    function () public payable { 
        revert(); 
    }//return funds minus gased used if wrongly sent

    function rentalAgreement (
        address specifiedHost, 
        address specifiedGuest,
        string bookingID, 
        uint rent,
        uint expTime) public 
        {
            tokensPerNight = rent;
            hostAddress = specifiedHost;
            guestAddress = specifiedGuest;
            arbiter = msg.sender;
            ContractStart(now, bookingID);
            // Convert date time into unix timestamp
            expirationTimestamp = expTime;
            bookingUUID = bookingID;
        }

    function payContract() public payable {
        if (msg.sender != guestAddress || contractPaid) { 
            revert();
        }
        tokensPerNight = msg.value;
        contractPaid = true;
        paidTime = now;
        ContractIsPaid(paidTime);
    }

    function satisfied() public onlyHost onlyGuest {
        if (msg.sender == hostAddress) {
            hostSatisfied = true;
        }else {
            guestSatisfied = true;
        }
    }

    function payout() public {
        if (guestSatisfied && hostSatisfied) {
            BothSatisfied(true);
            ContractEnded(now, bookingUUID);
            selfdestruct(hostAddress);
        }else {
            BothSatisfied(false);
            ContractEnded(now, bookingUUID);
            selfdestruct(arbiter);
        }
    }

    //function fallback() internal {
    //    ContractEnded(now, bookingUUID);
    //    selfdestruct(arbiter);
    //}

    //function tokenTransfer(uint tokenPrice, address tokenAddress) {
    //}

}
