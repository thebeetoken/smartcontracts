pragma solidity ^0.4.18; 
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "zeppelin-solidity/contracts/token/BurnableToken.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

/*
 * BeeToken is a standard ERC20 token with some additional functionalities:
 * - Transfers are only enabled after contract owner enables it (after the ICO)
 * - Contract sets 30% of the total supply as allowance for ICO contract
 *
 * Note: Token Offering == Initial Coin Offering(ICO)
 */

contract BeeToken is StandardToken, BurnableToken, Ownable {
    string public constant symbol = "BEE";
    string public constant name = "Bee Token";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 500000000 * (10 ** uint256(decimals));
    uint256 public constant TOKEN_OFFERING_ALLOWANCE = 150000000 * (10 ** uint256(decimals));
    uint256 public constant ADMIN_ALLOWANCE = INITIAL_SUPPLY - TOKEN_OFFERING_ALLOWANCE;
    
    // Address of token admin
    address public adminAddr;
    // Address of token offering
    address public tokenOfferingAddr;
    // Enable transfers after conclusion of token offering
    bool public transferEnabled = false;
    
    /**
     * Check if transfer is allowed
     *
     * Permissions:
     *                                                       Owner    Admin    OffeirngContract    Others
     * transfer (before transferEnabled is true)               x        x            x               x
     * transferForm (before transferEnabled is true)           x        v            v               x
     * transfer/transferFrom after transferEnabled is true     v        x            x               v
     */
    modifier onlyWhenTransferAllowed() {
        require(transferEnabled || msg.sender == adminAddr || msg.sender == tokenOfferingAddr);
        _;
    }

    /**
     * Check if token offering address is set or not
     */
    modifier onlyTokenOfferingAddrNotSet() {
        require(tokenOfferingAddr == address(0x0));
        _;
    }

    /**
     * Check if address is a valid destination to transfer tokens to
     * - must not be zero address
     * - must not be the token address
     * - must not be the owner's address
     * - must not be the admin's address
     * - must not be the token offering contract address
     */
    modifier validDestination(address to) {
        require(to != address(0x0));
        require(to != address(this));
        require(to != owner);
        require(to != address(adminAddr));
        require(to != address(tokenOfferingAddr));
        _;
    }
    
    /**
     * Token contract constructor
     *
     * @param admin Address of admin account
     */
    function BeeToken(address admin) public {
        totalSupply = INITIAL_SUPPLY;
        
        // Mint tokens
        balances[msg.sender] = totalSupply;
        Transfer(address(0x0), msg.sender, totalSupply);

        // Approve allowance for admin account
        adminAddr = admin;
        approve(adminAddr, ADMIN_ALLOWANCE);
    }

    /**
     * Set token offering to approve allowance for offering contract to distribute tokens
     *
     * @param offeringAddr Address of token offerng contract
     * @param amountForSale Amount of tokens for sale, set 0 to max out
     */
    function setTokenOffering(address offeringAddr, uint256 amountForSale) external onlyOwner onlyTokenOfferingAddrNotSet {
        require(!transferEnabled);

        uint256 amount = (amountForSale == 0) ? TOKEN_OFFERING_ALLOWANCE : amountForSale;
        require(amount <= TOKEN_OFFERING_ALLOWANCE);

        approve(offeringAddr, amount);
        tokenOfferingAddr = offeringAddr;
    }
    
    /**
     * Enable transfers
     */
    function enableTransfer() external onlyOwner {
        transferEnabled = true;

        // End the offering
        approve(tokenOfferingAddr, 0);
    }

    /**
     * Transfer from sender to another account
     *
     * @param to Destination address
     * @param value Amount of beetokens to send
     */
    function transfer(address to, uint256 value) public onlyWhenTransferAllowed validDestination(to) returns (bool) {
        return super.transfer(to, value);
    }
    
    /**
     * Transfer from `from` account to `to` account using allowance in `from` account to the sender
     *
     * @param from Origin address
     * @param to Destination address
     * @param value Amount of beetokens to send
     */
    function transferFrom(address from, address to, uint256 value) public onlyWhenTransferAllowed validDestination(to) returns (bool) {
        return super.transferFrom(from, to, value);
    }
    
    /**
     * Burn token, only owner is allowed to do this
     *
     * @param value Amount of tokens to burn
     */
    function burn(uint256 value) public {
        require(transferEnabled || msg.sender == owner);
        super.burn(value);
    }
}