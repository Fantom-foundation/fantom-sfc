const { govAbi } = require('../compiled/abi');
const { govBin } = require('../compiled/bin');
const TransactionHandler = require('../common/govTransactions');
const AccountsHandler = require('../common/accountsHandler');
const config = require('../config');

class GovernanceContract {
    constructor(web3) {

        this.web3 = web3;
        this.accountHandler = new AccountsHandler(web3);
        this.TransactionHandler = new TransactionHandler(web3);
        this.contractConstructor =  new this.web3.eth.Contract(govAbi);
        // this.contract = new this.web3.eth.Contract(govAbi, this.contractAddress); 
    }

    async init() {
        await this.accountHandler.init();
    }

    deploy(governableContractAddr) {
        this.contractConstructor.deploy({
            data: `0x${govBin}`,
            // You can omit the asciiToHex calls, as the contstructor takes strings. 
            // Web3 will do the conversion for you.
            arguments: [governableContractAddr] 
        }).send({
            from: address,
            gasPrice: gasPrice,
            gas: gas + 500000
        }).then((instance) => {
            console.log("Contract mined at " + instance.options.address);
        });
    }
}

module.exports = GovernanceContract;