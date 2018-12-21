pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Arbitration {
    function requestArbitration(
        bytes32 id,
        uint256 tokens,
        address supplier,
        address purchaser
    )
        external;
}

contract TestArbitration is Arbitration, Ownable {
    event Arbitrate(
        bytes32 id,
        uint256 tokens,
        address supplier,
        address purchaser
    );

    function requestArbitration(
        bytes32 id,
        uint256 tokens,
        address supplier,
        address purchaser
    )
        external
    {
        emit Arbitrate(id, tokens, supplier, purchaser);
    }
}
