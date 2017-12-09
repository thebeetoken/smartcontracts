`BeeToken.sol` is ERC20-compatible and has the following characteristics:

1. A fixed supply of pre-minted tokens
2. The ability to burn tokens by a user, removing the tokens from the supply
3. Tokens are allocated upon conclusion of the Token Offering. `BeeTokenOffering.sol` is given an allowance of tokens to be sold on behalf of the token owner


`BeeTokenOffering.sol` strategy is as follows:

* In order to participate users must be whitelisted.
* During the first 48 hours, more engaged users will have the opportunity to purchase more tokens. Tier A-D will be able to contribute 300%, 200%, 150%, and 100%, respectively, of the base contribution amount described by: Base(Tier D) = ETH hard cap / (#A*3 + #B*2 + #C*1.5 + #D)
 * #T = number of people in respective tier
* After the first 48 hours, if tokens have not sold out, all users will have their allocations increased up to double their original amount. This period will last for 48 hours. 
* After 96 hours, any remaining tokens can be purchased by whitelisted users without restrictions up until the end date.
* Tokens are allocated to contributors upon conclusion of token offering.

`BeeTokenOffering.sol` flow:

1. Constructor initializes token offering with: Bee Token contract address, Beneficiary address, Token to ETH rate, and base ETH cap (max contribution in ETH for base tier).
2. Owner will assign participants into whitelisted tiers before starting token offering with whitelist functions.
3. Owner can start the sale by calling startOffering. Doing so will assign start time, as well as time for phase shifts.


Upon reaching the ETH contribution cap or end time of the token offering:

1. Allocate tokens to participants
2. Burn all unallocated tokens
3. Enable the ability to transfer tokens for everyone

Once these final two steps are performed, the distribution of tokens is complete.


We use OpenZeppelin code for `SafeMath`, `Ownable`, `Burnable`, `Pausable`, and `StandardToken` logic.

* `SafeMath` provides arithmetic functions that throw exceptions when integer overflow occurs
* `Ownable` keeps track of a contract owner and permits the transfer of ownership by the current owner
* `Burnable` provides a burn function that decrements the balance of the burner and the total supply
* `StandardToken` provides an implementation of the ERC20 standard
* `Pausable` allows owner to pause the Token Offering contract 
