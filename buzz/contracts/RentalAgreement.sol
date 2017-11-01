pragma solidity ^0.4.16;


contract RentalAgreement {
    bool complete; //replace with state transitions
    address guestAddress;
    address hostAddress;
    address arbiter; //sent to this address if bad transaction
    uint rentValue;
    uint completeTime;
    bool hostSatisfied = false;
    bool guestSatisfied = false;
    uint expirationTimestamp;
    string bookingUUID;

    event ContractIsComplete(uint timestamp);
    event ContractStart(uint timestamp, string bookingUUID);
    event ContractEnded(uint timestamp, string bookingUUID);

    modifier guestHostOnly() {
        if (msg.sender != guestAddress || msg.sender != hostAddress) {
            revert();
        } else {
            _;
        }
    }

    modifier notExpired() {
        if (block.timestamp >= expirationTimestamp) {
            fallback(); //send funds to arbiter
            revert();
        } else {
            _;
        }
    }

    function()  public { revert(); }//return funds minus gased used if wrongly sent

    function rentalAgreement (
        address specifiedHost, 
        address specifiedGuest, 
        string rentTitle, 
        uint expiry)  
        public 
        {
        hostAddress = specifiedHost;
        guestAddress = specifiedGuest;
        arbiter = msg.sender;
        contractStart(block.timestamp, rentTitle);
        expirationTimestamp = block.timestamp + expiry;
        bookingUUID = rentTitle;
    }

    function payContract() public payable {
        if (msg.sender != guestAddress || complete) { 
            revert();
        }
        rentValue = msg.value;
        complete = true;
        completeTime = block.timestamp;
        contractIsComplete(completeTime);
    }

    function satisfied() public guestHostOnly notExpired {
        if (msg.sender == hostAddress) {
            hostSatisfied = true;
        }else {
            guestSatisfied = true;
        }
        if (guestSatisfied && hostSatisfied) {
            payout();
        }
    }

    function payout() internal {
        contractEnded(block.timestamp, bookingUUID);
        selfdestruct(hostAddress); //sends money to host
    }

    function fallback() internal {
        contractEnded(block.timestamp, bookingUUID);
        selfdestruct(arbiter);
    }

}


