# Arbitration

## Install Dependencies

    npm install

This has been tested with some globally installed packages; in case of 
problems, try:

    npm install -g truffle ganache-cli

## Compile

    truffle compile

## Test

Run Ganache before testing:

    ganache-cli --allowUnlimitedContractSize true --gasLimit 800000000 --gasPrice 1

The allowUnlimitedContractSize flag gets by ganache's low byte code limit on contracts (it was small like this before on main net and test net but they increased the size a while back.  Given that, the arbitration contract rubs pretty close against the new limit). The gas limit on main net is 8 million but for some reason the gas prices for instructions are wrong on ganache and it cost way more to deploy (Arbitration.sol runs about 6-7 million gas, to clear that you'll need gas price a little higher than normal because a high gas price for 3 million as would knock you out of the deploy for a given block block).

### Automated

    truffle test

Note that this fast-forwards time in Ganache as part of the testing
flow; restart Ganache afterwards to restore connection to real time.

### Manual

Deploy contracts to Ganache:

    truffle migrate

## Deploy

### Testnet

To deploy to Ropsten, create a file named `.env` file in this directory, the contents of which
should look like:

    ROPSTEN_URI=https://ropsten.infura.io/v3/<API Key>
    ROPSTEN_MNEMONIC='twelve word mnemonic goes here...'

You will also need to transfer Ropsten ETH to the account associated
with this mnemonic to cover gas costs.

After that, run:

    truffle migrate --network ropsten
    
You can use my infura API key and an eth account I've loaded with eth already:

    ROPSTEN_URI=https://ropsten.infura.io/v3/71eef437e1e14883a2e51bb5ec27ec68
    ROPSTEN_MNEMONIC='that snap dash warfare collect trim chunk judge address worry online barely'

More details
https://medium.com/coinmonks/deploy-your-smart-contract-directly-from-truffle-with-infura-ba1e1f1d40c2
