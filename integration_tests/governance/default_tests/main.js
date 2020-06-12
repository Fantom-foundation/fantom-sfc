const {deploySfc} = require('./sfcStuff');
const {deployLrc, linkGovBin} = require('./preDeployment');
const GovContract = require('./governanceContract');
const TransactionHandler = require('../common/sfcTransactions');
const Web3 = require('web3');
const config = require('../config');

const endpoint = `http://${config.defaultTestsConfig.defaultHost}:${config.defaultTestsConfig.defaultPort}`;

async function runTests() {
    try {
        const web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
        const { govContract, sfcTransactions } = await deployContracts(web3);
        const voters = await createVoters(govContract, sfcTransactions, 10);

        console.log('works');
    }
    catch(e) {
        console.log(`runTests error:\n${e}`)
    }
}

async function deployContracts(web3) {
    const govContract = new GovContract(web3);
    await govContract.init();
    
    const coinbase = await govContract.accountHandler.getCoinbase();
    const sfcContract = await deploySfc(web3, coinbase);
    await deployLrc(web3, coinbase);

    const govBin = linkGovBin();
    const govAddr = await govContract.deploy(govBin, coinbase);
    await govContract.reInit(web3, govAddr);
    const sfcTransactions = new TransactionHandler(web3, sfcContract, config.defaultTestsConfig.sfcContractAddress);
    return {govContract, sfcTransactions};
}

async function createVoters(govContract, sfcContract, num) {
    const payer = await govContract.accountHandler.getPayer();
    payer.address = payer.keyObject.address;

    const startVotes = await govContract.transactions.getTotalVotes(payer.address, 0);
    const createdAddresses = [];
    const accBalance = "3175001";
    const stakeBalance = "3175000";
    for (let i = 0; i < num; i++) {
        const newAccAddr = await govContract.accountHandler.createAccountWithBalance(payer, accBalance, true);
        createdAddresses.push(newAccAddr);
    }

    for (let i = 0; i < num; i++) {
        await sfcContract.createStake(createdAddresses[i], stakeBalance, "0x");
        // createdAddresses.push(newAccAddr);
    }
    const endVotes = await govContract.transactions.getTotalVotes(payer.address, 0);
    
    const sn = await sfcContract.getStakersNum();
    console.log();
}



module.exports = runTests;