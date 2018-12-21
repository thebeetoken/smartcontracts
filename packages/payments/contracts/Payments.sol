pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./Arbitration.sol";

contract Whitelist is Ownable {
    mapping(address => bool) public whitelisted;

    function whitelist(address caller, bool enabled) public onlyOwner {
        whitelisted[caller] = enabled;
    }

    modifier onlyWhitelisted() {
        require(whitelisted[msg.sender], "Approved callers only.");
        _;
    }
}

contract Payments is Ownable {
    struct Details {
        bool active;
        address supplier;
        uint64 cancelDeadline;
        address purchaser;
        uint64 disputeDeadline;
        uint256 price;
        uint256 deposit;
        uint256 cancellationFee;
    }

    event Invoice (
        bytes32 id,
        address supplier,
        address purchaser,
        uint256 price,
        uint256 deposit,
        uint256 cancellationFee,
        uint64 cancelDeadline,
        uint64 disputeDeadline
    );
    event Payout (
        bytes32 id,
        address supplier,
        address purchaser,
        uint256 price,
        uint256 deposit
    );
    event Cancel (
        bytes32 id,
        address supplier,
        address purchaser,
        uint256 price,
        uint256 deposit,
        uint256 cancellationFee
    );
    event Refund (
        bytes32 id,
        address supplier,
        address purchaser,
        uint256 price,
        uint256 deposit
    );
    event Dispute (
        bytes32 id,
        address arbitration,
        address disputant,
        address supplier,
        address purchaser,
        uint256 price,
        uint256 deposit
    );

    modifier onlyPurchaser(bytes32 id) {
        require(msg.sender == details[id].purchaser, "Purchaser only.");
        _;
    }

    modifier onlySupplier(bytes32 id) {
        require(msg.sender == details[id].supplier, "Supplier only.");
        _;        
    }

    modifier onlyOwnerOrSupplier(bytes32 id) {
        require(
            msg.sender == owner ||
            msg.sender == details[id].supplier,
            "Owner or supplier only."
        );
        _;
    }

    modifier onlyParticipant(bytes32 id) {
        require(
            msg.sender == details[id].supplier ||
            msg.sender == details[id].purchaser,
            "Participant only."
        );
        _;
    }

    modifier deactivates(bytes32 id) {
        require(details[id].active, "Unknown id.");
        details[id].active = false;
        _;
    }

    modifier invoices(bytes32 id) {
        require(details[id].supplier == 0x0, "Given id already exists.");
        _;
        emit Invoice(
            id,
            details[id].supplier,
            details[id].purchaser,
            details[id].price,
            details[id].deposit,
            details[id].cancellationFee,
            details[id].cancelDeadline,
            details[id].disputeDeadline
        );
    }

    modifier pays(bytes32 id) {
        /* solium-disable-next-line security/no-block-members */
        require(now > details[id].disputeDeadline, "Dispute deadline not met.");
        _;
        emit Payout(
            id,
            details[id].supplier,
            details[id].purchaser,
            details[id].price,
            details[id].deposit
        );
    }

    modifier cancels(bytes32 id) {
        /* solium-disable-next-line security/no-block-members */
        require(now < details[id].cancelDeadline, "Cancel deadline passed.");
        _;
        emit Cancel(
            id,
            details[id].supplier,
            details[id].purchaser,
            details[id].price,
            details[id].deposit,
            details[id].cancellationFee
        );
    }

    modifier refunds(bytes32 id) {
        _;
        emit Refund(
            id,
            details[id].supplier,
            details[id].purchaser,
            details[id].price,
            details[id].deposit
        );
    }

    modifier disputes(bytes32 id) {
        /* solium-disable-next-line security/no-block-members */
        require(now < details[id].disputeDeadline, "Dispute deadline passed.");
        _;
        emit Dispute(
            id,
            arbitration,
            msg.sender,
            details[id].supplier,
            details[id].purchaser,
            details[id].price,
            details[id].deposit
        );
    }

    mapping(bytes32 => Details) public details;
    Arbitration public arbitration;
}

contract TokenPayments is Whitelist, Payments {
    using SafeMath for uint256;

    ERC20 public token;
    uint64 public cancelPeriod;
    uint64 public disputePeriod;

    constructor(
        address _token,
        address _arbitration,
        uint64 _cancelPeriod,
        uint64 _disputePeriod
    )
        public
    {
        token = ERC20(_token);
        arbitration = Arbitration(_arbitration);
        cancelPeriod = _cancelPeriod;
        disputePeriod = _disputePeriod;
    }

    function invoice(
        bytes32 id,
        address supplier,
        address purchaser,
        uint256 price,
        uint256 deposit,
        uint256 cancellationFee,
        uint64 cancelDeadline,
        uint64 disputeDeadline
    )
        external
        onlyWhitelisted
        invoices(id)
    {
        require(
            supplier != address(0x0),
            "Must provide a valid supplier address."
        );
        require(
            purchaser != address(0x0),
            "Must provide a valid purchaser address."
        );
        require(
            /* solium-disable-next-line security/no-block-members */
            cancelDeadline > now.add(cancelPeriod),
            "Cancel deadline too soon."
        );
        require(
            disputeDeadline > uint256(cancelDeadline).add(disputePeriod),
            "Dispute deadline too soon."
        );
        require(
            price.add(deposit) >= cancellationFee,
            "Cancellation fee exceeds total."
        );
        details[id] = Details({
            active: true,
            supplier: supplier,
            cancelDeadline: cancelDeadline,
            purchaser: purchaser,
            disputeDeadline: disputeDeadline,
            price: price,
            deposit: deposit,
            cancellationFee: cancellationFee
        });
        uint256 expectedBalance = getTotal(id)
            .add(token.balanceOf(address(this)));
        require(
            token.transferFrom(purchaser, address(this), getTotal(id)),
            "Transfer failed during invoice."
        );
        require(
            token.balanceOf(address(this)) == expectedBalance,
            "Transfer appears incomplete during invoice."
        );
    }

    function cancel(bytes32 id) 
        external
        onlyPurchaser(id)
        deactivates(id)
        cancels(id)
    {
        uint256 fee = details[id].cancellationFee;
        uint256 refund = getTotal(id).sub(fee);
        transfer(details[id].purchaser, refund);
        transfer(details[id].supplier, fee);
    }

    function payout(bytes32 id)
        external
        onlySupplier(id)
        deactivates(id)
        pays(id)
    {
        transfer(details[id].supplier, details[id].price);
        transfer(details[id].purchaser, details[id].deposit);
    }

    function refund(bytes32 id)
        external
        onlyOwnerOrSupplier(id)
        deactivates(id)
        refunds(id)
    {
        transfer(details[id].purchaser, getTotal(id));
    }

    function dispute(bytes32 id)
        external
        onlyParticipant(id)
        deactivates(id)
        disputes(id)
    {
        require(
            token.approve(arbitration, getTotal(id)),
            "Approval for transfer failed during dispute."
        );
        arbitration.requestArbitration(
            id,
            getTotal(id),
            details[id].supplier,
            details[id].purchaser
        );
    }

    function getTotal(bytes32 id) private view returns (uint256) {
        return details[id].price.add(details[id].deposit);
    }

    function transfer(address to, uint256 amount) internal {
        uint256 expectedBalance = token.balanceOf(address(this)).sub(amount);
        uint256 expectedRecipientBalance = token.balanceOf(to).add(amount);
        require(token.transfer(to, amount), "Transfer failed.");
        require(
            token.balanceOf(address(this)) == expectedBalance,
            "Post-transfer validation of contract funds failed."
        );
        require(
            token.balanceOf(to) == expectedRecipientBalance,
            "Post-transfer validation of recipient funds failed."
        );
    }
}

