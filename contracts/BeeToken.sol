pragma solidity ^0.4.18; 
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "zeppelin-solidity/contracts/token/BurnableToken.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

contract BeeToken is StandardToken, BurnableToken, Ownable {
    // Note: Token Offering == Initial Coin Offering(ICO)

    string public constant symbol = "BEE";
    string public constant name = "Bee Token";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 500000000 * (10 ** uint256(decimals));
    uint256 public constant TOKEN_OFFERING_ALLOWANCE = 150000000 * (10 ** uint256(decimals)); // Currently 30%
    uint256 public constant ADMIN_ALLOWANCE = 350000000 * (10 ** uint256(decimals)); // 70%
    
    address public adminAddr;               // Address of token admin
    address public tokenOfferingAddr;       // Address of token offering
    bool    public transferEnabled = false; // Enable transfers after conclusion of token offering
    
    modifier onlyWhenTransferEnabled() {
        // transfer for adminAddr and tokenOfferingAddr is enabled any time
        // transfer for regular users is only enabled once token owner explicitly enables it by calling enableTransfer
        require(transferEnabled || msg.sender == adminAddr || msg.sender == tokenOfferingAddr);
        _;
    }

    modifier onlyTokenOfferingAddrNotSet() {
        require(tokenOfferingAddr == address(0x0));
        _;
    }

    modifier validDestination(address _to) {
        require(_to != address(0x0));
        require(_to != address(this));
        require(_to != owner);
        require(_to != address(adminAddr));
        require(_to != address(tokenOfferingAddr));
        _;
    }
    
    function BeeToken(address _adminAddr) public {
        totalSupply = INITIAL_SUPPLY;
        balances[msg.sender] = totalSupply; // Mint tokens
        Transfer(address(0x0), msg.sender, totalSupply);

        adminAddr = _adminAddr;
        approve(adminAddr, ADMIN_ALLOWANCE);
    }

    function setTokenOffering(address _tokenOfferingAddr, uint256 _amountForSale) external onlyOwner onlyTokenOfferingAddrNotSet {
        require(!transferEnabled);

        uint256 amount = (_amountForSale == 0) ? TOKEN_OFFERING_ALLOWANCE : _amountForSale;
        require(amount <= TOKEN_OFFERING_ALLOWANCE);

        approve(_tokenOfferingAddr, amount);
        tokenOfferingAddr = _tokenOfferingAddr;
    }
    
    function enableTransfer() external onlyOwner {
        transferEnabled = true;

        // End the offering
        approve(tokenOfferingAddr, 0);
    }

    function transfer(address _to, uint256 _value) public onlyWhenTransferEnabled validDestination(_to) returns (bool) {
        return super.transfer(_to, _value);
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public onlyWhenTransferEnabled validDestination(_to) returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }
    
    function burn(uint256 _value) public {
        require(transferEnabled || msg.sender == owner);
        super.burn(_value);
    }
}