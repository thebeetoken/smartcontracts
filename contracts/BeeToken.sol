pragma solidity ^0.4.18; 
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/zeppelin-solidity/contracts/token/StandardToken.sol";
import "../node_modules/zeppelin-solidity/contracts/token/BurnableToken.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";


contract BeeToken is StandardToken, BurnableToken, Ownable {
    // Note: Token Offering == Initial Coin Offering(ICO)
    // Constants
    string public constant symbol = "BEE";
    string public constant name = "Bee Token";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 500000000 * 1 ether;
    uint256 public constant TOKEN_OFFERING_ALLOWANCE = 150000000 * 1 ether; // Currently 30%
    uint256 public constant ADMIN_ALLOWANCE = 450000000 * 1 ether; // 70%
    
    
    uint256 public adminAllowance;          // Number of tokens
    uint256 public tokenOfferingAllowance;  // Number of tokens
    address public adminAddr;               // Address of token admin
    address public tokenOfferingAddr;       // Address of token offering
    bool    public transferEnabled = false; // Enable transfers after conclusion of token offering
    
    modifier onlyWhenTransferEnabled() {
        if (!transferEnabled) {
            require(msg.sender == adminAddr || msg.sender == tokenOfferingAddr);
        }
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
    
    function BeeToken(address _admin) public {
        
        totalSupply = INITIAL_SUPPLY;
        tokenOfferingAllowance = TOKEN_OFFERING_ALLOWANCE;
        adminAllowance = ADMIN_ALLOWANCE;


        balances[msg.sender] = totalSupply;               // Mint tokens
        Transfer(address(0x0), msg.sender, totalSupply);

        adminAddr = _admin;
        approve(adminAddr, adminAllowance);
    }

    function setTokenOffering(address _tokenOfferingAddr, uint256 _amountForSale) external onlyOwner {
        require(!transferEnabled);
        require(_amountForSale <= tokenOfferingAllowance);

        uint amount = (_amountForSale == 0) ? tokenOfferingAllowance : _amountForSale;

        // Clear allowance of old, and set allowance of new
        approve(tokenOfferingAddr, 0);
        approve(_tokenOfferingAddr, amount);

        tokenOfferingAddr = _tokenOfferingAddr;
    }
    
    function enableTransfer() external onlyOwner {
        transferEnabled = true;
        approve(tokenOfferingAddr, 0);
        approve(adminAddr, 0);
        tokenOfferingAllowance = 0;
        adminAllowance = 0;
    }

    function transfer(address _to, uint256 _value) public onlyWhenTransferEnabled validDestination(_to) returns (bool) {
        return super.transfer(_to, _value);
    }
    
    function transferFrom(address _from, address _to, uint256 _value) 
    public onlyWhenTransferEnabled validDestination(_to) returns (bool) {
        bool result = super.transferFrom(_from, _to, _value);
        if (result) {
            if (msg.sender == tokenOfferingAddr)
                tokenOfferingAllowance = tokenOfferingAllowance.sub(_value);
            if (msg.sender == adminAddr)
                adminAllowance = adminAllowance.sub(_value);
        }
        return result;
    }
    
    function burn(uint256 _value) public {
        require(transferEnabled || msg.sender == owner);
        require(balances[msg.sender] >= _value);
        super.burn(_value);
        Transfer(msg.sender, address(0x0), _value);
    }
}