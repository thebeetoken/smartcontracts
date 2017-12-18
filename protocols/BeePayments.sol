pragma solidity ^0.4.16;

import '../contracts/token/ERC20.sol';
import '../contracts/math/SafeMath.sol';

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
        bool exist;
        PaymentStatus paymentStatus;
        bytes32 paymentId; // keccak256 hash of all fields
        address paymentTokenContractAddress;
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

    function () public payable {}
    
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
        address arbitrationAddress,
        uint cost,
        uint securityDeposit,
        uint demandCancellationFee,
        uint demandCancelByTimeInS,
        uint supplyCancellationFee,
        uint supplyCancelByTimeInS,
        uint paymentDispatchTimeInS
    ) public returns(bool) {
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
            arbitrationAddress,
            cost,
            securityDeposit,
            demandCancellationFee,
            demandCancelByTimeInS,
            supplyCancellationFee,
            supplyCancelByTimeInS,
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
    ) public payable onlyPaymentStatus(paymentId, PaymentStatus.INITIALIZED) demandOrSupplyEntity(paymentId) returns (bool) {
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
    function dispatchPayments() public {
        // TODO: check daily in progress payments, and pay appropirate accounts.
        // TODO: move successful payments from in progress to completed
    }
    
    /**
     * Cancels that payment in progress. Runs canclation rules as appropriate.
     * @return true if cancel is successful, false otherwise
     */ 
    function cancelPayment(bytes32 paymentId) public returns(bool) {
        // TODO: check cancelation rules and pay as appropirate
        // TODO: move payment from in progress to cancel
    }
    
    /**
     * Moves the in progress payment into arbitration.
     */ 
    function disputePayment(bytes32 paymentId) public {
        // TODO: pass escrow to Bee Arbitration protocol
        // TODO: move from in progress to arbitration
    }
    
    /**
     * Used to get all info about the payment.
     * @return all info of the payment, including payment id and status.
     */
    function getPaymentStatus(bytes32 paymentId)
        public
        constant
        returns(PaymentStruct) {
            if (allPayments[paymentId].exist) {
                return allPayments[paymentId];
            } else {
                revert();
            }
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
