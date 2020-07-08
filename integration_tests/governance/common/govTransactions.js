const EthUtil = require('ethereumjs-util');
const Tx = require('ethereumjs-tx').Transaction;
let fs = require("fs");
const Web3 = require('web3');
// var Tx = require('ethereumjs-tx');


class TransactionHandler {
    constructor(web3, governance, contractAddr, txStorage) {
        this.web3 = web3;
        this.governance = governance;
        this.contractAddr = contractAddr;
        this.txStorage = txStorage;
    }

    deploy() {

    }

    async createProposal(from, value, proposalContract, requiredDeposit) {
        const nonce = await this.web3.eth.getTransactionCount(from);
        const gasPrice = await this.web3.eth.getGasPrice();

        const txMsg = {
            from: from,
            to: this.contractAddr,
            value: value,
            data: this.governance.methods.createProposal(proposalContract, requiredDeposit).encodeABI(),
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce)
        }

        let txHash;
        await this.web3.eth.sendTransaction(txMsg, function(err, hash) {
            if (err) 
                throw(err);

            if (hash) {
                console.log("tx sendSignedTransaction hash:", hash); 
                txHash = hash;
            }
        });
        return txHash;
    };

    async increaseProposalDeposit(from, value, proposalId) {
        const nonce = await this.web3.eth.getTransactionCount(from);
        const gasPrice = await this.web3.eth.getGasPrice();

        const txMsg = {
            from: from,
            to: this.contractAddr,
            value: value,
            data: this.governance.methods.increaseProposalDeposit(proposalId).encodeABI(),
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce)
        }

        let txHash;
        await this.web3.eth.sendTransaction(txMsg, function(err, hash) {
            if (err) 
                throw(err);

            if (hash) {
                console.log("tx sendSignedTransaction hash:", hash); 
                txHash = hash;
            }
        });
        return txHash;
    }

    async vote(from, proposalId, choises) {
        const nonce = await this.web3.eth.getTransactionCount(from);
        const gasPrice = await this.web3.eth.getGasPrice();

        const txMsg = {
            from: from,
            to: this.contractAddr,
            value: "0",
            data: this.governance.methods.vote(proposalId, choises).encodeABI(),
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce)
        }

        let txHash;
        await this.web3.eth.sendTransaction(txMsg, function(err, hash) {
            if (err) 
                throw(err);

            if (hash) {
                console.log("tx sendSignedTransaction hash:", hash); 
                txHash = hash;
            }
        });
        return txHash;
    }

    async handleDeadlines(from, startIdx, quantity) {
        const nonce = await this.web3.eth.getTransactionCount(from);
        const gasPrice = await this.web3.eth.getGasPrice();

        const txMsg = {
            from: from,
            to: this.contractAddr,
            value: "0",
            data: this.governance.methods.handleDeadlines(startIdx, quantity).encodeABI(),
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce)
        }

        let txHash;
        await this.web3.eth.sendTransaction(txMsg, function(err, hash) {
            if (err) 
                throw(err);

            if (hash) {
                console.log("tx sendSignedTransaction hash:", hash); 
                txHash = hash;
            }
        });
        return txHash;
    }

    getTotalVotes(from, propType) {
        return new Promise(resolve => {
            this.governance.methods.totalVotes(propType).call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    };
    
    async estimateGas(rawTx) {
        let estimateGas;
        await this.web3.eth.estimateGas(rawTx, (err, gas) => {
            if (err)
                throw(err);

            estimateGas = gas;
        });

        return estimateGas;
    };


    async newTx({
        from,
        to,
        value,
        memo = '',
        web3Delegate = '',
        turnLogsOff = false,
    }) {
        const useWeb3 = web3Delegate || this.web3;
        const nonce = await useWeb3.eth.getTransactionCount(from);
        const gasPrice = await useWeb3.eth.getGasPrice();
        // const txName
        
        const rawTx = {
            from: from,
            to,
            value: value,
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce),
            data: memo
        };
        
        // if (!turnLogsOff)
        //     console.log("rawTx", rawTx);
        
        //let estimatedGas = await this.estimateGas(rawTx);
        //rawTx.gasLimit = this.web3.utils.toHex(estimatedGas);
        
        return this.web3.eth.sendTransaction(rawTx, function(err, hash) {
        if (err) { throw(err); }
        if (!turnLogsOff) { console.log("tx sendSignedTransaction hash:", hash); }
        
        
        });
    };

    async newSignedTx({
                       accountFrom,
                       to,
                       value,
                       memo = '',
                       web3Delegate = '',
                       turnLogsOff = false,
                   }) {
        const useWeb3 = web3Delegate || this.web3;
        const nonce = await useWeb3.eth.getTransactionCount(accountFrom.address);
        const gasPrice = await useWeb3.eth.getGasPrice();
        // const txName
        
        const rawTx = {
            from: accountFrom.address,
            to,
            value: this.web3.utils.toHex(this.web3.utils.toWei(value, 'ether')),
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce),
            data: memo
        };
        
        // if (!turnLogsOff)
        //     console.log("rawTx", rawTx);

        let estimatedGas = await this.estimateGas(rawTx);
        rawTx.gasLimit = this.web3.utils.toHex(estimatedGas);

        let tx = await this.web3.eth.accounts.signTransaction(rawTx, accountFrom.privateKey);
        return this.web3.eth.sendSignedTransaction(tx.rawTransaction, function(err, hash) {
            if (err) { throw(err); }
            if (!turnLogsOff) { console.log("tx sendSignedTransaction hash:", hash); }


        });
    };
}



module.exports = TransactionHandler;
