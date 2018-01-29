const assert = require('assert');
const fs = require('fs');
const parseSync = require('csv-parse/lib/sync');
const program = require('commander');
const Web3 = require('web3');

const abiPath = '../build/BeeTokenOffering.json';
const addressKey = 'eth_address';
const beeAllocationKey = 'bee_allocation';
const chunkSize = 1;
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

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

    const logs = await handle(inputFile, outputFile);
    console.log(`${logs}`);
}

run().then(function () {
    console.log('Done!');
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

    // const getAccounts = (cb) => {
    //     web3.eth.getAccounts(cb);
    // };

    // const result = await promisify(getAccounts);
    // console.log(`${result}`);
    return Promise.all(promiseCalls);;
}

function splitIntoChunks(data, chunkSize) {
    let chunks = [];

    if (array.length < chunkSize) {
        chunkSize = array.length;
    }

    for (let i = 0, j = array.length; i < j; i += chunkSize) {
        const tmp = array.slice(i, i + chunkSize);
        chunks.push(tmp);
    }

    return chunks;
}

function allocateTokensCall(chunk) {
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

    const call = offering.batchAllocateTokensBeforeOffering.call.bind(
        offering, destAddresses, allocationAmounts
    );

    return promisify(call);
}

function validateData(allRows) {
    allRows.forEach((row) => {
        const addr = row[addressKey];
        assert.ok(addr);
        assert.equal(addr.length, 42, 'Address must be 42 length');
        const amount = row[beeAllocationKey];
        assert.ok(amount);
        assert.ok(parseInt(amount) > 0, 'Bee allocation must be greater than 0');
    });
}

// HELPERS
function promisify(inner) {
    return new Promise((resolve, reject) =>
        inner((err, res) => {
            if (err) { reject(err) }

            resolve(res);
        })
    );
}
