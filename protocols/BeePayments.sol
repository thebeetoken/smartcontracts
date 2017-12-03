pragma solidity ^0.4.16;


contract BeePayments {
    
    
    enum PaymentStatus {
        NOT_FOUND,      // payment does not exist
        INITIALIZED,    // awaiting payment from supply & demand entities
        IN_PROGRESS,    // awaiting dispatch time to pass, or a dispute
        IN_ARBITRATION, // dispute has been raised, to be handled by Arbitration
        CANCELED,       // payment canceled 
        COMPLETED       // payment successful 
    }

    
    // We can call functions inside of structs. Might be nice to have a callback in here
    struct PaymentStruct {
        
        bytes32 paymentId; // keccak256 hash of all fields
        PaymentStatus paymentStatus;
        address supplyEntityAddress;
        address demandEntityAddress;
        address arbitrationAddress;
        uint cost;
        uint securityDeposit;
        uint demandCancellationFee;
        uint demandCancelByTimeInS;
        uint supplyCancellationFee;
        uint supplyCancelByTimeInS;
        uint paymentDispatchTimeInS;
    }
    
    // TODO: define events
    event Pay();
    event CancelPayment();
    event DisputePayment();
    
    // TODO: define modifiers
    modifier demandPaid(bytes32 _paymentHash) {
        _;
    }
    modifier supplyPaid(bytes32 _paymentHash) {
        _;
    }
    
    // maps the paymentIds to the struct
    mapping (bytes32 => PaymentStruct) allPayments;
    // newly initialized payments: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) initializedPayments;
    // payments in flight: day in sec => list of payment ids (hashes)
    mapping (uint => bytes32[]) inProgressPayments;  // 
    // paymentes in arbitration: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) inArbitrationPayments;
    // completed payments: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) completedPayments;
    // canceled payments: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) canceledPayments;
    
    function BeePayments() public {}

    function () public payable {
        _;
    }
    
    /**
     * Initializes a new payment, and awaits for supply & demand entities to
     * pay.
     * 
     * @return a payment id for the caller to keep.
     */
    function initPayment() public returns(bytes32) {
        // TODO: create a new payment struct and add to the allPayments mapping
        return 0;
    }
    
    /**
     * To be invoked by entities to pay.
     */
    function pay(bytes32 paymentHash) 
        public
        payable
        demandPaid(paymentHash)
        supplyPaid(paymentHash) {
            // TODO: once the full amount is reached, move from initialized to 
            // in progress
        }
    
    /**
     * Dispatches in progress payments daily based on paymentDispatchTimeInS.
     */ 
    function dispatchPayments() public {
        // TODO: check daily in progress payments, and pay appropirate accounts.
        // TODO: move successful payments from in progress to completed
    }
    
    /**
     * Cancels that payment in progress. Runs canclation rules as appropriate.
     * @return true if cancel is successful, false otherwise
     */ 
    function cancelPayment(bytes32 paymentHash) public returns(bool) {
        // TODO: check cancelation rules and pay as appropirate
        // TODO: move payment from in progress to cancel
    }
    
    /**
     * Moves the in progress payment into arbitration.
     */ 
    function disputePayment(bytes32 paymentHash) public {
        // TODO: pass escrow to Bee Arbitration protocol
        // TODO: move from in progress to arbitration
    }
    
    /**
     * Used to get all info about the payment.
     * @return all info of the payment, including payment id and status.
     */
    function getPaymentStatus(bytes32 paymentHash)
        public
        constant
        returns(PaymentStruct) {
            // TODO: return NOT_FOUND if payment not present.
            return allPayments[paymentHash];
        }
    
    // TODO: createPaymentStruct and createPaymentId
    /*
    function createPaymentStruct() private
        returns(PaymentStruct) {
        return 0;
    }
    
    function createPaymentId() private
        returns(bytes32) {
        return 0;
    }
    */
}
