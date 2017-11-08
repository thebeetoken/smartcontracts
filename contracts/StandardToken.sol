pragma solidity ^0.4.17;
import "./SafeMath.sol";

contract Token {
    uint256 public _totalSupply;
    bool public releaseFunds = false;
    address public travelAnywhereFundDeposit; // deposit address for TravelAnywhere Tokens
    uint256 public totalEthereum = 0; // Hold the total value of Ethereum of the entire pool, used to calculate cashout/burn.
    function totalSupply() constant returns (uint256 totalSupply);
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
    function stake(uint256 _value) constant returns (bool success);
    function balanceStaked(address _owner) constant returns (uint256 staked);
    function unstake(uint256 _value) constant returns (bool success);
    function burn(uint256 _amount) constant returns (bool success);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Stake(address indexed _from, uint256 _value);
    event UnStake(address indexed _from, uint256 _value);
    event Burn(address indexed _owner, uint256 _value);
    
    // extra functionality while live
    bool public allowTransfers = false; // Stop transfers during ICO.
    uint256 public saleStart;
}


/*  ERC 20 token */
contract StandardToken is Token {
    using SafeMath for uint256;
    
    function totalSupply() constant returns (uint256 totalSupply) {
      totalSupply = _totalSupply;
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
      if (!allowTransfers) return false;
      //if Travel Anywhere is trying to trade, check that it's been 1 year.
      if (msg.sender == travelAnywhereFundDeposit) {
          if(!releaseFunds) return false;
      }
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
      if (!allowTransfers) return false;
      //if TravelAnywhere Inc. is trying to trade, check that it's been 1 year.
      if (_from == travelAnywhereFundDeposit) {
          if(!releaseFunds) return false;
      }
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }
    
    function stake(uint256 _value) constant returns (bool success) {
        if (!allowTransfers) return false; // Don't allow staking during the ICO.
        if (balances[msg.sender] < _value) return false; // Check to make sure they are not staking more than they have.
        balances[msg.sender] -= _value;
        staking[msg.sender] += _value;
        Stake(msg.sender, _value);
    }
    
    function balanceStaked(address _owner) constant returns (uint256 staked) {
        return staking[_owner];
    }

    function unstake(uint256 _value) constant returns (bool success) {
        if (!allowTransfers) return false; // Don't allow staking during the ICO.
        if (staking[msg.sender] < _value) return false; // Make sure they can't unstake more than they have staked.
        balances[msg.sender] += _value;
        staking[msg.sender] -= _value;
        UnStake(msg.sender, _value);
    }
    
    //Allow token holders to cash out and burn their tokens.
    //The backend will handle the math and sending the eth since Solidity isn't efficient at math nor is it precise enough.
    function burn(uint256 _value) constant returns (bool success) {
        if (!allowTransfers) return false; //Don't allow burning during payouts.
        if (now < saleStart + (60 days)) return false; //Don't allow burn/cashout for 2 months. TEST
        _totalSupply -= _value;
        balances[msg.sender] -= _value;
        Burn(msg.sender, _value);
    }
    
    mapping (address => uint256) balances;
    mapping (address => uint256) staking;
    mapping (address => uint256) rewards;
    mapping (address => mapping (address => uint256)) allowed;
}
