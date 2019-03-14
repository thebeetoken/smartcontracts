# Reputation 

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
    
More details
https://medium.com/coinmonks/deploy-your-smart-contract-directly-from-truffle-with-infura-ba1e1f1d40c2
