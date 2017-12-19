pragma solidity ^0.4.18;

import '../contracts/token/StandardToken.sol';
import '../contracts/math/SafeMath.sol';


contract BeePayments is Ownable{ 
    
    
    using SafeMath for uint;
    address public arbitrationAddress;
    uint arbitrationFee; // tbd. 

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
        bool exist;
        PaymentStatus paymentStatus;
        bytes32 paymentId; // keccak256 hash of all fields
        address paymentTokenContractAddress;
        address supplyEntityAddress;
        address demandEntityAddress;
        uint cost;
        uint securityDeposit;
        uint demandCancellationFee;
        uint supplyCancellationFee;
        uint cancelDeadlineInS;
        uint paymentDispatchTimeInS;
        bool demandPaid;
        bool supplyPaid;
    }
    
    // TODO: define events
    event Pay();
    event CancelPayment();
    event DisputePayment();
    
    // TODO: define modifiers
    modifier demandPaid(bytes32 paymentId) {
        _;
    }
    
    modifier supplyPaid(bytes32 paymentId) {
        _;
    }

    modifier demandOrSupplyEntity(bytes32 paymentId) {
        require(
            msg.sender == allPayments[paymentId].demandEntityAddress ||
            msg.sender == allPayments[paymentId].supplyEntityAddress
        );
        _;
    }

    modifier onlyPaymentStatus(bytes32 paymentId, PaymentStatus paymentStatus) {
        require(allPayments[paymentId].paymentStatus == paymentStatus);
        _;
    }
    
    
    // maps the paymentIds to the struct
    mapping (bytes32 => PaymentStruct) public allPayments;
    // newly initialized payments: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) public initializedPayments;
    // payments in flight: day in sec => list of payment ids (hashes)
    mapping (uint => bytes32[]) public inProgressPayments;  // 
    // paymentes in arbitration: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) public inArbitrationPayments;
    // completed payments: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) public completedPayments;
    // canceled payments: paymentIds => amount of tokens expected
    mapping (bytes32 => uint) public canceledPayments;
    // maps token address to mapping of payment balances. Make sure only admin can update token contract list
    //mapping (address => mapping (address => uint)) public tokenContract;
    
    function BeePayments(address admin_, address arbitrationAddress_) public {
        arbitrationAddress = arbitrationAddress_;
    }

    function () public payable {}
    
    function updateArbitrationAddress(address arbitrationAddress_) public onlyOwner {
        arbitrationAddress = arbitrationAddress_;
    }
    
    /**
     * Initializes a new payment, and awaits for supply & demand entities to
     * pay.
     * 
     * @return a payment id for the caller to keep.
     */
    function initPayment(
        bytes32 paymentId,
        address paymentTokenContractAddress,
        address demandEntityAddress,
        address supplyEntityAddress,
        uint cost,
        uint securityDeposit,
        uint demandCancellationFee,
        uint supplyCancellationFee,
        uint cancelDeadlineInS,
        uint paymentDispatchTimeInS
    ) public onlyOwner returns(bool)
    {
        if (allPayments[paymentId].exist) {
            revert();
            // return false;
        }

        allPayments[paymentId] = PaymentStruct(
            true,
            PaymentStatus.INITIALIZED,
            paymentId,
            paymentTokenContractAddress,
            demandEntityAddress,
            supplyEntityAddress,
            cost,
            securityDeposit,
            demandCancellationFee,
            supplyCancellationFee,
            cancelDeadlineInS,
            paymentDispatchTimeInS,
            false,
            false
        );
        return true;
    }
    
    /**
     * To be invoked by entities to pay.
     */
    function pay(
        bytes32 paymentId
    ) public
    payable
    onlyPaymentStatus(paymentId, PaymentStatus.INITIALIZED)
    demandOrSupplyEntity(paymentId)
    returns (bool)
    {
        PaymentStruct storage payment = allPayments[paymentId];
        ERC20 tokenContract = ERC20(payment.paymentTokenContractAddress);
        if (msg.sender == payment.demandEntityAddress) {
            uint256 amountToPay = SafeMath.add(
                payment.securityDeposit,
                SafeMath.add(
                    payment.demandCancellationFee,
                    payment.cost
                )
            );
            if (tokenContract.approve(this, amountToPay)) {
                payment.demandPaid = true;
            } else {
                return false;
            }
        } else {
            if (tokenContract.approve(this, payment.supplyCancellationFee)) {
                payment.supplyPaid = true;
            } else {
                return false;
            }
        }

        if (payment.demandPaid && payment.supplyPaid) {
            payment.paymentStatus = PaymentStatus.IN_PROGRESS;
        }
        return true;
    }
    
    /**
     * Dispatches in progress payments daily based on paymentDispatchTimeInS.
     */
    function dispatchPayments() public pure {
        // TODO: check daily in progress payments, and pay appropirate accounts.
        // TODO: move successful payments from in progress to completed
        revert();
    }
    
    /**
     * Cancels that payment in progress. Runs canclation rules as appropriate.
     * @return true if cancel is successful, false otherwise
     */ 
    function cancelPayment(bytes32 paymentId) public demandOrSupplyEntity(paymentId) returns(bool) {
        // TODO: check cancelation rules and pay as appropirate
        // TODO: move payment from in progress to cancel
        if(msg.sender == payment.demandEntityAddress) {
            // transfer demandCancellationFee to supply entity
            
            // return funds to respective entities
            
        }
    }
    
    /**
     * Moves the in progress payment into arbitration.
     */ 
    function disputePayment(bytes32 paymentId) public demandOrSupplyEntity(paymentId){
        // TODO: pass escrow to Bee Arbitration protocol
        // TODO: move from in progress to arbitration
        if(msg.sender == payment.demandEntityAddress) {
            // msg.sender pays arbitrationFee
            // decrease token amount of sender, transfer it to arbitration address
        }
    }
    
    /**
     * Used to get all info about the payment.
     * @return all info of the payment, including payment id and status.
     */
    function getPaymentStatus(bytes32 paymentId)
        public
        view
        returns(PaymentStruct)
    {
        if (allPayments[paymentId].exist) {
            return allPayments[paymentId];
        } else {
            revert();
        }
    }
    
    // TODO: createPaymentStruct and createPaymentId
    /*
    function createPaymentStruct() internal
        returns(PaymentStruct) {
        return 0;
    }
    
    function createPaymentId() internal
        returns(bytes32) {
        return 0;
    }
    */
}