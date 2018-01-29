const assert = require('assert');
const fs = require('fs');
const parseSync = require('csv-parse/lib/sync');
const program = require('commander');
const Web3 = require('web3');

const abiPath = '../build/contracts/BeeTokenOffering.json';
const addressKey = 'eth_address';
const beeAllocationKey = 'bee_allocation';
const chunkSize = 1;
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

/**
 * Example: node allocate_presale.js -I presale_input.csv -O output.csv -C 0x_offering_contract_address
 */

program
    .version('1.0.0')
    .option('-I, --inputFile [value]', 'Input CSV file')
    .option('-O, --outputFile [value]', 'Output file, contain logs and transaction hashes')
    .option('-C, --contract [value]', 'Offering contract address')
    .parse(process.argv);

// RUN

async function run() {
    if (!program.inputFile || !program.outputFile) {
        throw new Error('Input and Output file must be specificed');
    }
    const inputFile = program.inputFile;
    const outputFile = program.outputFile;
    if (fs.existsSync(outputFile)) {
        throw new Error(`Output file '${outputFile}' already exists, specify a new one`);
    }
    if (!fs.existsSync(inputFile)) {
        throw new Error(`Input file '${inputFile}' doesn't exist, specify a new one`);
    }

    if (!program.contract) {
        throw new Error(`Must specify the offering contract address`);
    }

    if (!fs.existsSync(abiPath)) {
        throw new Error(`No abi file in the truffle build directory, run 'truffle migrate' to generate abi using the latest code`);
    }

    const transactions = await handle(inputFile, outputFile);
    console.log(`TRANSACTIONS: ${transactions}`);
    fs.writeFileSync(outputFile, transactions.join('\n'));
}

run().then(() => {
    console.log('Done!');
}).catch((err) => {
    console.log(`${err}`);
});

// FUNCTIONS

async function handle(inputFile, outputFile) {
    const data = fs.readFileSync(inputFile);
    const allRows = parseSync(data, {
        columns: true, // auto discover column names in the first line
        delimiter: ',',
    });

    validateData(allRows);

    const chunks = splitIntoChunks(allRows, chunkSize);

    const promiseCalls = chunks.map((c) => {
        return allocateTokensCall(c);
    });

    const logs = await Promise.all(promiseCalls);
    return logs;
}

function splitIntoChunks(allRows, chunkSize) {
    let chunks = [];

    if (allRows.length < chunkSize) {
        chunkSize = allRows.length;
    }

    for (let i = 0, j = allRows.length; i < j; i += chunkSize) {
        const tmp = allRows.slice(i, i + chunkSize);
        chunks.push(tmp);
    }

    return chunks;
}

async function allocateTokensCall(chunk) {
    const contractAddr = program.contract;
    const abi = require(abiPath).abi;

    const contractABI = web3.eth.contract(abi);
    const offering = contractABI.at(contractAddr);

    const destAddresses = chunk.map((o) => {
        return o[addressKey];
    });

    const allocationAmounts = chunk.map((o) => {
        return o[beeAllocationKey];
    });

    const accounts = await promisify((cb) => {
        web3.eth.getAccounts(cb);
    });


    return promisify(function (cb) {
        const callData = offering.batchAllocateTokensBeforeOffering.getData(destAddresses, allocationAmounts);
        const transactionData = { to: contractAddr, from: accounts[0], data: callData };
        web3.eth.sendTransaction(transactionData, cb);
    });
}

function validateData(allRows) {
    allRows.forEach((row) => {
        const addr = row[addressKey];
        assert.ok(addr, `${addressKey} needs to be set`);
        assert.equal(addr.length, 42, `${addressKey} must be 42 length`);
        const amount = row[beeAllocationKey];
        assert.ok(amount, `${beeAllocationKey} needs to be set`);
        assert.ok(parseInt(amount) > 0, `${beeAllocationKey} must be greater than 0`);
    });
}

// HELPERS
function promisify(inner) {
    return new Promise((resolve, reject) =>
        inner((err, res) => {
            if (err) { return reject(err); }

            resolve(res);
        })
    );
}
