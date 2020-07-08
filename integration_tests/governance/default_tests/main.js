const {deploySfc} = require('./sfcStuff');
const { propFacAbi } = require('../compiled/abi');
const {deployLrc, linkGovBin, deployDummySfc, deployProposalFactory} = require('./preDeployment');
const ProposalFactory = require("./proposalFactoryContract");
const GovContract = require('./governanceContract');
const TransactionHandler = require('../common/sfcTransactions');
const Web3 = require('web3');
const config = require('../config');

const endpoint = `http://${config.defaultTestsConfig.defaultHost}:${config.defaultTestsConfig.defaultPort}`;

async function runTests() {
    try {
        const web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
        const { govContract, proposalFactory, sfcTransactions, dummySfcAddr } = await deployContracts(web3);
        // const voters = await createVoters(govContract, sfcTransactions, 2);
        await resolveProposal(web3,  govContract, proposalFactory, dummySfcAddr);

        console.log('works');
    }
    catch(e) {
        console.log(`runTests error:\n${e}`)
    }
}

async function resolveProposal(web3, govContract, proposalFactory, dummySfcAddr) {
    const coinbase = await govContract.accountHandler.getCoinbase();
    const newProposalAddress = await proposalFactory.newSoftwareUpgradeProposal(coinbase, dummySfcAddr);
    console.log("newProposalAddress", newProposalAddress);

    const deposit = "1500";
    const startDeposit = "150";
    let txHash = await govContract.transactions.createProposal(coinbase, startDeposit, newProposalAddress, deposit);
    console.log("create proposal tx", txHash);
    let receipt = await web3.eth.getTransactionReceipt(txHash);
    let receiptData = receipt.logs[0].data;
    let inputs = [{
        type: 'uint256',
        name: 'proposalId'
    }];
    let topics = ["0xfd9732adde846a19b596a7f5b72cce832b433844e7c3921219e44a83d7295bac"];
    let decodeRes = web3.eth.abi.decodeLog(inputs, receiptData, topics);
    const newProposalId = decodeRes.proposalId;
    console.log("newProposalId", newProposalId);

    //increaseProposalDeposit

    txHash = await govContract.transactions.increaseProposalDeposit(coinbase, deposit, newProposalId);

    // sleep
    // Я НЕ ПОНИМАЮ ЧТО ТУТ ПРОИСХОДИТ!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    await new Promise(r => setTimeout(r, 60000));
    txHash = await govContract.transactions.handleDeadlines(coinbase, "0", "40");

    // await new Promise(r => setTimeout(r, 45001));
    const voteChoises = ["1", "0"];
    txHash = await govContract.transactions.vote(coinbase, newProposalId, voteChoises);

    await new Promise(r => setTimeout(r, 60000));
    txHash = await govContract.transactions.handleDeadlines(coinbase, "0", "40");
}

async function deployContracts(web3) {
    const govContract = new GovContract(web3);
    await govContract.init();
    
    const coinbase = await govContract.accountHandler.getCoinbase();
    const sfcContract = await deploySfc(web3, coinbase);
    const proxySfc = config.defaultTestsConfig.sfcContractAddress;
    await deployLrc(web3, coinbase);
    let proposalFactory = new ProposalFactory(web3);
    await proposalFactory.init(coinbase, proxySfc);

    const govBin = linkGovBin();
    const govAddr = await govContract.deploy(govBin, coinbase, proposalFactory.contractAddress);
    await govContract.reInit(web3, govAddr);
    const sfcTransactions = new TransactionHandler(web3, sfcContract, proxySfc);
    
    const dummySfcAddr = await deployDummySfc(web3, coinbase);
    return {govContract, proposalFactory, sfcTransactions, dummySfcAddr};
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
    }
    const endVotes = await govContract.transactions.getTotalVotes(payer.address, 0);
    
    const sn = await sfcContract.getStakersNum();
    console.log();
}



module.exports = runTests;