# Payments

## Install Dependencies

    npm install

This has been tested with some globally installed packages; in case of 
problems, try:

    npm install -g truffle webpack webpack-cli ganache-cli http-server

## Compile

    truffle compile

## Verification

### Test

Run Ganache before testing:

    ganache-cli

Then run the test suite:

    npm test

Note that this fast-forwards time in Ganache as part of the testing
flow; restart Ganache afterwards to restore connection to real time.

### Coverage

To run the test suite with code coverage reporting enabled:

    npm run cover

### Lint

To run [Solium](https://www.npmjs.com/package/solium) for source code
linting:

    npm run lint

## Deploy

### Testnet

To deploy to Ropsten, create a `.env` file, the contents of which
should look like:

    ROPSTEN_URI=https://ropsten.infura.io/v3/<API Key>
    ROPSTEN_MNEMONIC='twelve word mnemonic goes here...'

You will also need to transfer Ropsten ETH to the account associated
with this mnemonic to cover gas costs.

After that, run:

    truffle migrate --network ropsten

## Specification

The Payments contract manages and facilitates the flow of tokenized
funds associated with a consumer purchase.

This contract provides one method to initiate payment, and three
methods corresponding to payment outcomes.

1. A purchaser makes an `approve` call on a token contract, which
   permits subsequent transfer of funds to the Payments contract.
2. A supplier makes an `invoice` call to the Payments contract,
   initiating transfer of funds which will be held until an outcome.
   These funds include the price of purchase as well as a security
   deposit.
3. After that, the purchaser is able to `cancel` the purchase up
   to a deadline specified in the invoice call. A cancellation fee
   is charged.
4. After the cancellation deadline passes, both parties are able to
   `dispute` the purchase up until a deadline; on a dispute, the
   funds are transferred to an Arbitration contract which is
   responsible for subsequent allocation to resolve the dispute.
5. After the dispute deadline passes, the supplier is able to make
   a `payout` call to receive their funds; the security deposit is
   returned to the purchaser at that time.
6. To correct errors and prevent misuse, either the designated supplier
   or the contract owner is able to call a `refund` method up until the
   time of payout, returning funds to the purchaser without any
   cancellation fee.

### Inheritance

#### Ownable

The Payments contract inherits functionality from Open Zeppelin's
[`Ownable`](https://github.com/OpenZeppelin/openzeppelin-solidity/blob/v1.12.0/contracts/ownership/Ownable.sol)
base contract. In particular, this provides an `owner` property
which is defined initially as the contract's creator, as well as
an `onlyOwner` modifier to restrict certain calls to this address.

Inheriting from `Ownable` exposes two methods:

* `transferOwnership(address newOwner)` designates a new address
  as the contract owner.
* `renounceOwnership()` internally specifies the contract owner
  to the null address `0x0`, effectively reverting the contract
  to an ownerless state.

As technology maturation continues, transitioning to a completely
ownerless peer-to-peer model may be facilitated by the use of
`renounceOwnership()` (made visible through the public `owner` property)
or through deploying new iterations of the Payments contract.

#### Whitelist

The Payments contract additionally inherits from an internally
defined `Whitelist` base contract. It defines one method:

* `whitelist(address caller, bool enabled)`: Enable or disable
  this address in the whitelist. Restricted to [`onlyOwner`](#Ownable).

Additionally, `Whitelist` defines an `onlyWhitelisted` modifier which
allows calls only from addresses enabled via the `whitelist` method.

### Constructor

At the time an instance of the Payments contract is deployed, it is
initialized with the following parameters:

* `address _token`: The address of the token contract used to fund
  payments with this contract. New contracts may be deployed to support
  additional tokens.
* `address _arbitration`: The address of the arbitration contract used
  to handle disputes.
* `uint64 _cancelPeriod`: The minimum period of time, in seconds, during
  which cancellation should be possible, relative to the time of invoice.
* `uint64 _disputePeriod`: The minimum period of time, in seconds, during
  which dispute should be possible, relative to the cancellation deadline.

### Methods

#### invoice()

An `invoice` call transfers funds equal to the total of the indicated
price and deposit from a purchaser to the Payments contract, contingent
on a previous `approve` call made to the associated token contract by that
purchaser. Deadlines for cancellation and dispute are also specified at
this time. The contract will reject `invoice` calls which fail to provide
the time periods configured for the contract at the time of deployment, as
well as calls for which the transfer of funds fails (for instance, when a
purchaser has not made an `approve` call for those funds). Only
[whitelisted](#Whitelist) addresses may make `invoice` calls.

An `Invoice` event is emitted after a successful `invoice` call.

An `invoice` call is parameterized as follows:

* `bytes32 id`: A unique identifier to associate with this payment.
* `address supplier`: The destination for funds from the purchase price.
* `address purchaser`: The address from which to withdraw funds for the
  purchase.
* `uint256 price`: The price of purchase, in units used by the associated
  token contract.
* `uint256 deposit`: An additional deposit to hold from the purchaser,
  to be used in the event of a dispute, in units used by the associated
  token contract.
* `uint256 cancellationFee`: The cost of cancellation for the purchaser,
  in units used by the associated token contract.
* `uint64 cancelDeadline`: The deadline for cancellation, in seconds
  elapsed since the UNIX epoch (January 1, 1970).
* `uint64 disputeDeadline`: The deadline for disputes, in seconds
  elapsed since the UNIX epoch (January 1, 1970).

#### cancel()

A `cancel` stops a purchase in progress. A cancellation fee is deducted
from the total funds associated with the purchase and transferred to
the supplier, and remaining funds are returned to the purchaser. This
call is restricted to the purchaser, and calls made after the cancellation
deadline will be rejected.

A `Cancel` event is emitted after a successful `cancel` call.

A `cancel` call accepts a single parameter:

* `bytes32 id`: The identifier associated with this payment.

#### dispute()

A `dispute` call indicates that the purchase has not proceeded as agreed,
and requests that a decision on how to allocate funds be made by via
an arbitration process. Either (and only) the purchaser or supplier
associated with a payment may invoke this call, and calls made after the
dispute deadline will be rejected.

A `Dispute` event is emitted after a successful `dispute` call.

A `dispute` call accepts a single parameter:

* `bytes32 id`: The identifier associated with this payment.

#### payout()

A `payout` call indicates that a purchase has completed to the
satisfaction of the supplier, transferring the purchase price to the
supplier and returning the deposit to the purchaser. To ensure an
opportunity to dispute the payment, calls to `payout` will be rejected
unless the dispute deadline has been passed.

A `Payout` event is emitted after a successful `payout` call.

A `payout` call accepts a single parameter:

* `bytes32 id`: The identifier associated with this payment.

#### refund()

A `refund` call returns all funds associated with a previously-initiated
payment to the purchaser. Only a purchase's supplier or the contract
owner (if any) may initiate a refund.

A `Refund` event is emitted after a successful `refund` call.

A `refund` call accepts a single parameter:

* `bytes32 id`: The identifier associated with this payment.

### Events

#### Invoice

An `Invoice` event is emitted after a successful `invoice` call.

An `Invoice` event includes the following properties:

* `bytes32 id`: A unique identifier associated with this payment.
* `address supplier`: The destination for funds from the purchase price.
* `address purchaser`: The purchaser associated with this payment.
* `uint256 price`: The price of purchase, in units used by the associated
  token contract.
* `uint256 deposit`: The additional deposit held from the purchaser,
  in units used by the associated token contract.
* `uint256 cancellationFee`: The cost of cancellation for the purchaser,
  in units used by the associated token contract.
* `uint64 cancelDeadline`: The deadline for cancellation, in seconds
  elapsed since the UNIX epoch (January 1, 1970).
* `uint64 disputeDeadline`: The deadline for disputes, in seconds
  elapsed since the UNIX epoch (January 1, 1970).

#### Cancel

A `Cancel` event is emitted after a successful `cancel` call.

A `Cancel` event includes the following properties:

* `bytes32 id`: A unique identifier associated with this payment.
* `address supplier`: The destination for funds from the purchase price.
* `address purchaser`: The purchaser associated with this payment.
* `uint256 price`: The price of purchase, in units used by the associated
  token contract.
* `uint256 deposit`: The additional deposit held from the purchaser,
  in units used by the associated token contract.
* `uint256 cancellationFee`: The cost of cancellation for the purchaser,
  in units used by the associated token contract.

#### Dispute

A `Dispute` event is emitted after a successful `dispute` call.

A `Dispute` event includes the following properties:

* `bytes32 id`: A unique identifier associated with this payment.
* `address arbitration`: The address of the arbitration contract which
  will handle this dispute.
* `address disputant`: The address which initiated this dispute.
* `address supplier`: The destination for funds from the purchase price.
* `address purchaser`: The purchaser associated with this payment.
* `uint256 price`: The price of purchase, in units used by the associated
  token contract.
* `uint256 deposit`: The additional deposit held from the purchaser,
  in units used by the associated token contract.

#### Payout

A `Payout` event is emitted after a successful `payout` call.

A `Payout` event includes the following properties:

* `bytes32 id`: A unique identifier associated with this payment.
* `address supplier`: The destination for funds from the purchase price.
* `address purchaser`: The purchaser associated with this payment.
* `uint256 price`: The price of purchase, in units used by the associated
  token contract.
* `uint256 deposit`: The additional deposit held from the purchaser,
  in units used by the associated token contract.

#### Refund

A `Refund` event is emitted after a successful `refund` call.

A `Refund` event includes the following properties:

* `bytes32 id`: A unique identifier associated with this payment.
* `address supplier`: The destination for funds from the purchase price.
* `address purchaser`: The purchaser associated with this payment.
* `uint256 price`: The price of purchase, in units used by the associated
  token contract.
* `uint256 deposit`: The additional deposit held from the purchaser,
  in units used by the associated token contract.
