pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/ERC20.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';


contract BeePayments is Ownable { 
    
    
    using SafeMath for uint256;
    address public arbitrationAddress;
    uint256 public arbitrationFee;

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
        address demandEntityAddress;
        address supplyEntityAddress;
        uint256 cost;
        uint256 securityDeposit;
        uint256 demandCancellationFee;
        uint256 supplyCancellationFee;
        uint64 cancelDeadlineInS;
        uint64 paymentDispatchTimeInS;
        bool demandPaid;
        bool supplyPaid;
    }
    
    // TODO: define events
    //event Pay(address user, bool paid, uint amount);
    //event CancelPayment(uint time, uint amount);
    //event DisputePayment(uint time, uint amount);

    // TODO: define modifiers
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

    function BeePayments(address arbitrationAddress_, uint256 arbitrationFee_) public {
        arbitrationAddress = arbitrationAddress_;
        arbitrationFee = arbitrationFee_;
    }

    function () public payable {
        revert();
    }
    
    function updateArbitrationAddress(address arbitrationAddress_) public onlyOwner {
        arbitrationAddress = arbitrationAddress_;
    }

    function updateArbitrationFee(uint256 arbitrationFee_) public onlyOwner {
        arbitrationFee = arbitrationFee_;
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
        uint256 cost,
        uint256 securityDeposit,
        uint256 demandCancellationFee,
        uint supplyCancellationFee,
        uint64 cancelDeadlineInS,
        uint64 paymentDispatchTimeInS
    ) public onlyOwner returns(bool success)
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
    // must call approve on token contract to allow pay to transfer on their behalf
    function pay(
        bytes32 paymentId
    ) public
    onlyPaymentStatus(paymentId, PaymentStatus.INITIALIZED)
    demandOrSupplyEntity(paymentId)
    returns (bool success)
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
            if (tokenContract.transferFrom(msg.sender, this, amountToPay)) {
                payment.demandPaid = true;
            }
        } else {
            if (tokenContract.transferFrom(msg.sender, this, payment.supplyCancellationFee)) {
                payment.supplyPaid = true;
            }
        }

        if (payment.demandPaid && payment.supplyPaid) {
            payment.paymentStatus = PaymentStatus.IN_PROGRESS;
        }
        return true;
    }
    
    function dispatchPayment(bytes32 paymentId) public onlyPaymentStatus(paymentId, PaymentStatus.IN_PROGRESS) {
        PaymentStruct storage payment = allPayments[paymentId];
        ERC20 tokenContract = ERC20(payment.paymentTokenContractAddress);
        require(payment.paymentDispatchTimeInS <= now);
        
        uint256 supplyPayout = SafeMath.add(payment.supplyCancellationFee, payment.cost);
        uint256 demandPayout = SafeMath.add(payment.demandCancellationFee, payment.securityDeposit);
        
        if (tokenContract.transfer(payment.supplyEntityAddress, supplyPayout)
            && tokenContract.transfer(payment.demandEntityAddress, demandPayout)) {
            payment.paymentStatus = PaymentStatus.COMPLETED;
        }
    }
    /**
     * Dispatches in progress payments daily based on paymentDispatchTimeInS.
     * This will only be the happy path
     */
    // Make a function to get the list of inProgress payments mapping. 
    function dispatchPayments(bytes32[] paymentId) external {
        // TODO: check daily in progress payments, and pay appropirate accounts.
        // TODO: move successful payments from in progress to completed
        // check gas costs - limit iterating through every IN_PROGRESS payment
        
        for (uint32 i = 0; i < paymentId.length; i++) {
            dispatchPayment(paymentId[i]);
        }
    }

    /**
     * Cancels that payment in progress. Runs canclation rules as appropriate.
     * @return true if cancel is successful, false otherwise
     */
    function cancelPayment(bytes32 paymentId) public demandOrSupplyEntity(paymentId) returns(bool success) {
        PaymentStruct storage payment = allPayments[paymentId];
        ERC20 tokenContract = ERC20(payment.paymentTokenContractAddress);
        // replace now with oracle time
        if (payment.cancelDeadlineInS < now) {
            uint256 amountReturnedDemand = SafeMath.add(
                payment.securityDeposit,
                SafeMath.add(
                    payment.demandCancellationFee,
                    payment.cost
                )
            );
            if (tokenContract.transfer(payment.demandEntityAddress, amountReturnedDemand)
                && tokenContract.transfer(payment.supplyEntityAddress, payment.supplyCancellationFee)) {
                payment.paymentStatus = PaymentStatus.CANCELED;
            }
        } else {
            if (msg.sender == payment.demandEntityAddress) {
            // transfer demandCancellationFee to supply entity
                amountReturnedDemand = SafeMath.add(
                    payment.securityDeposit,
                    payment.cost
                );
                uint256 amountReturnedSupply = SafeMath.add(
                    payment.supplyCancellationFee,
                    payment.demandCancellationFee
                );
                if (tokenContract.transfer(msg.sender, amountReturnedDemand)
                    && tokenContract.transfer(payment.supplyEntityAddress, amountReturnedSupply)) {
                    payment.paymentStatus = PaymentStatus.CANCELED;
                }
            } else {
                // Return demand entity's money in addition to supply cancellation fee
                amountReturnedDemand = SafeMath.add(
                    payment.securityDeposit,
                    SafeMath.add(
                        payment.cost,
                        SafeMath.add(
                            payment.supplyCancellationFee,
                            payment.demandCancellationFee)
                    )
                );
                if (tokenContract.transfer(payment.demandEntityAddress, amountReturnedDemand)) {
                    payment.paymentStatus = PaymentStatus.CANCELED;
                }
            }
        }
        return true;
    }
    /**
     * Moves the in progress payment into arbitration.
     * Needs web3 approve call
     */

    function disputePayment(bytes32 paymentId) 
    public
    demandOrSupplyEntity(paymentId)
    onlyPaymentStatus(paymentId, PaymentStatus.IN_PROGRESS)
    returns(bool success)
    {
        // TODO: pass escrow to Bee Arbitration protocol
        // TODO: move from in progress to arbitration
        PaymentStruct storage payment = allPayments[paymentId];
        ERC20 tokenContract = ERC20(payment.paymentTokenContractAddress);
        uint256 total = SafeMath.add(
            payment.securityDeposit,
            SafeMath.add(
                payment.demandCancellationFee,
                SafeMath.add(
                    payment.cost,
                    payment.supplyCancellationFee
                )
            )
        );

        require(tokenContract.transferFrom(msg.sender, arbitrationAddress, arbitrationFee)
        && tokenContract.transfer(arbitrationAddress, total));
        payment.paymentStatus = PaymentStatus.IN_ARBITRATION;

        return true;
    }
    /**
     * Used to get all info about the payment.
     * @return all info of the payment, including payment id and status.
     */
    // Will not work until solidity version updates with #3272
    /*
    function getPaymentStatus(bytes32 paymentId) public view returns(PaymentStruct) {
        if (allPayments[paymentId].exist) {
            return allPayments[paymentId];
        } else {
            revert();
        }
    }
    */
}
