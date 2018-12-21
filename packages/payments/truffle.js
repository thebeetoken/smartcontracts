require('dotenv').config();

const HDWalletProvider = require('truffle-hdwallet-provider');
const ROPSTEN_MNEMONIC = process.env.ROPSTEN_MNEMONIC;
const ROPSTEN_URI = process.env.ROPSTEN_URI;

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    },
    ropsten: {
      provider: () => new HDWalletProvider(ROPSTEN_MNEMONIC, ROPSTEN_URI),
      network_id: '3'
    }
  }
};
