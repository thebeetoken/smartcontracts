/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a 
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() { 
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>') 
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */
require('dotenv').config();

const HDWalletProvider = require('truffle-hdwallet-provider');
const ROPSTEN_MNEMONIC = process.env.ROPSTEN_MNEMONIC;
const ROPSTEN_URI = process.env.ROPSTEN_URI;
const MAINNET_MNEMONIC = process.env.MAINNET_MNEMONIC;
const MAINNET_URI = process.env.MAINNET_URI;

module.exports = {
solc: {//optimized code for 2000 runs.  optimizes gas usage.  I think it might optimize byte code storage for contracts as well
  optimizer: {
    enabled: true,
    runs: 2000 //optimized as if the contract will be run 2000 times and then never used again.  high gas to deploy low gas to use
  }
},
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 80000000, //gas limit is 8 million on mainnet, arbitration contract takes about 6-7 million on mainnet but for some reason takes a lot more using truffle, prob the optimization flag isn't turned on
      gasPrice: 0x01
    },
    ropsten: {
      provider: () => new HDWalletProvider(ROPSTEN_MNEMONIC, ROPSTEN_URI),
      network_id: '3',
      gas: 8000000,      
      gasPrice:51200000000
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    },
    mainnet: {
      provider: () => new HDWalletProvider(MAINNET_MNEMONIC, MAINNET_URI),
      network_id: '1',
      gasPrice: 42 * Math.pow(10, 9) // 20 Gwei
    }
  }
};
