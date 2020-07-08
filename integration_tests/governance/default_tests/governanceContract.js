const { govAbi } = require('../compiled/abi');
// const { govBin } = require('../compiled/bin');
const TransactionHandler = require('../common/govTransactions');
const AccountsHandler = require('../common/accountsHandler');
const config = require('../config');

async function estimateGas(rawTx, web3) {
    let estimateGas;
    await web3.eth.estimateGas(rawTx, (err, gas) => {
        if (err)
            throw(err);

        estimateGas = gas;
    });

    return estimateGas;
};

class GovernanceContract {
    constructor(web3) {
        this.web3 = web3;
        this.accountHandler = new AccountsHandler(web3);
        this.transactions = new TransactionHandler(web3);
        this.contractConstructor =  new this.web3.eth.Contract(govAbi);
        // this.contract = new this.web3.eth.Contract(govAbi, this.contractAddress); 
    }

    async init() {
        await this.accountHandler.init();
    }

    async reInit(web3, contractAddr) {
        this.contractAddr = contractAddr;
        this.contract = new this.web3.eth.Contract(govAbi, this.contractAddr);
        this.web3 = web3;
        this.accountHandler = new AccountsHandler(web3);
        this.transactions = new TransactionHandler(web3, this.contract, this.contractAddr);
        this.contractConstructor =  new this.web3.eth.Contract(govAbi);
    }

    async deploy(govBin, from, proposalFactoryAddress) {
        const bin = `0x${govBin}`;
        const governableContractAddr = config.defaultTestsConfig.sfcContractAddress;
        const gasPrice = await this.web3.eth.getGasPrice();
        // let estimatedGas = await estimateGas(rawTx, this.web3);
        const memo = this.contractConstructor.deploy({
            data: bin,
            // You can omit the asciiToHex calls, as the contstructor takes strings. 
            // Web3 will do the conversion for you.
            arguments: [governableContractAddr, proposalFactoryAddress] 
        }).encodeABI();
        const rawTx = {
            data: memo,
            from: from
        }
        var x = this.contractConstructor.new;
        let estimatedGas = await estimateGas(rawTx, this.web3);
        let txHash;
        await this.web3.eth.sendTransaction(rawTx, (err, _txHash) => {
            if (err) {
                console.log("deploy governance err", err);
            }
            txHash = _txHash;
            console.log(`governance deployed. txHash: ${txHash}`);
        });
        let receipt = await this.web3.eth.getTransactionReceipt(txHash);
        let address = receipt.contractAddress;
        console.log("governance address:", address);
        return address;
    }
}

module.exports = GovernanceContract;