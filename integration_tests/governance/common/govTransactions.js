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

    advanceEpoch(from) {
        return this.newSignedTx({
            from: from,
            to: this.contractAddr,
            value: "0",
            memo: this.governance.methods.advanceEpoch().encodeABI(),
            gasLimit: 200000,
            web3Delegate: this.web3
        });
    };

    getStakersNum(from) {
        return new Promise(resolve => {
            this.governance.methods.stakersNum().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    };

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

    // doesnt work.
    // "new" is undefined
    // unnecessary lines are temprorary commented. will be removed or uncommentec in a future commits
    async deployContract(abi, code) {
        let web3 = this.web3;
        let newSfc = new web3.eth.Contract(abi);
        let coinBase;
        let password = "fakepassword";
        await web3.eth.getCoinbase((err, cb) => {
            coinBase = cb;
        })
        console.log("Unlocking coinbase account");
        
        
        console.log("Deploying the contract");
        console.log("web3.eth.сontract", web3.eth.сontract); // undefined        
        console.log("newSfc.new", newSfc.new); // undefined
        console.log("newSfc.eth", newSfc.eth); // undefined        
        console.log("web3.eth.contract", web3.eth.contract); // undefined
        console.log("web3.contract", web3.contract); // undefined
        let contract = await newSfc.new({from: web3.eth.coinbase, gas: 1000000, data: code});
        
        // Transaction has entered to geth memory pool
        console.log("Your contract is being deployed in transaction at http://testnet.etherscan.io/tx/" + contract.transactionHash);
        return; // exit here for testing purposes
        
        function sleep(ms) {
          return new Promise(resolve => setTimeout(resolve, ms));
        }
        
        // We need to wait until any miner has included the transaction
        // in a block to get the address of the contract
        async function waitBlock() {
          while (true) {
            let receipt = web3.eth.getTransactionReceipt(contract.transactionHash);
            if (receipt && receipt.contractAddress) {
                console.log("Your contract has been deployed at http://testnet.etherscan.io/address/" + receipt.contractAddress);
                console.log("Note that it might take 30 - 90 sceonds for the block to propagate befor it's visible in etherscan.io");
                break;
            }
            console.log("Waiting a mined block to include your contract... currently in block " + web3.eth.blockNumber);
            await sleep(4000);
          }
        }
        
        waitBlock();
        }
}



module.exports = TransactionHandler;
