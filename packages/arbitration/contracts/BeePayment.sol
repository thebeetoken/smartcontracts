pragma solidity ^0.4.24;

//import 'openzeppelin-solIdity/contracts/token/ERC20/ERC20.sol';
import './BeeArbitration.sol';
// okay this can't be a contract in the same file... need to figrue it out'
// contract BeeArbitration {
//     function requestArbitration(bytes32 paymentId, uint256 disputedBeeTokens, address host, address guest) external;
//     function normArbFee() external returns (uint256);
    
// }

contract BeePayment {
    
    ERC20 beeToken;  //bee token address TODO
    address beeArbitrationContractAddress;
    BeeArbitration beeArb;

    constructor (address beeTokenContractAddress, address arbitrationAddress)
    public 
    {
        beeArbitrationContractAddress = arbitrationAddress;
        beeToken = ERC20(beeTokenContractAddress);
        beeArb = BeeArbitration(beeArbitrationContractAddress);
    }
    
    function setArbitrationAddress(address arbitrationAddress) public {
        beeArbitrationContractAddress = arbitrationAddress;
        beeArb = BeeArbitration(beeArbitrationContractAddress);
    }
    
    
    function sendArbitrationRequest (address guest, address host, uint256 disputeAmt, bytes32 PaymentId) public  {
        //beeToken.mintFreeBeeTokens();
        disputeAmt = disputeAmt + beeArb.normArbFee();
        beeToken.approve(beeArbitrationContractAddress, disputeAmt);
        beeArb.requestArbitration(PaymentId, disputeAmt, guest, host);
        
    }
}

