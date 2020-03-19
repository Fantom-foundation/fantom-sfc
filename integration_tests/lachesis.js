const Web3 = require('web3');
const LachesisRpc = require('./lachesisRpc');
const SfcTransactions = require('./sfcTransactions');
const BN = Web3.utils.BN;

class lachesis {
    constructor(web3, sfc, contractAddress, upgradabilityProxy, txStorage) {
        this.contractAddress = contractAddress;
        this.web3 = web3;
        this.txStorage = txStorage;
        this.upgradabilityProxy = upgradabilityProxy;
        this.sfc = sfc;
        this.transactions = new SfcTransactions.TransactionHandler(web3, this.sfc, this.contractAddress, this.txStorage);
        this.rpc = new LachesisRpc.rpc();
    }

    // returns first transaction within N blocks or null if no transactions found
    async findLastTransaction(maxBlocksToInspect, newContractAddress) {
        let latestBlock = await this.rpc.getLatestBlock();
        let latestBlockNumber = new BN(this.web3.utils.hexToNumber(latestBlock.data.result.number));
        let prevBlockNum = latestBlockNumber;
        
        // let blockNum = latestBlockNumber;
        let txs = await this.transactionFromBlock(latestBlock);
        if (txs && txs.length != 0) {
            // console.log("txs 26", txs);
            return txs;
        }

        for (let i=0; i<maxBlocksToInspect; i++) {
            prevBlockNum = latestBlockNumber.sub(new BN(1));
            let block = await this.rpc.getLatestBlock(prevBlockNum);
            let txs = await this.transactionFromBlock(block);
            // console.log("txs", txs);
            if (txs && txs.length != 0) {
                // console.log("txs 35", txs);
                return txs;
            }
        }

        console.log("no transactions found within", maxBlocksToInspect, "blocks");
    }

    async transactionFromBlock(block) {
        return block.data.result.transactions;
    }

    async upgradeTo(accountFrom, address) {
        // console.log("typeof accountFrom", typeof accountFrom);
        const nonce = await this.web3.eth.getTransactionCount(accountFrom.address);
        const gasPrice = await this.web3.eth.getGasPrice();
        const to = this.contractAddress;
        const memo = this.upgradabilityProxy.methods.upgradeTo(address).encodeABI();

        const rawTx = {
            from: accountFrom.address,
            to: to,
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce),
            data: memo
        };
        let estimatedGas = await this.estimateGas(rawTx);
        rawTx.gasLimit = this.web3.utils.toHex(estimatedGas);
        let signedTx = await this.web3.eth.accounts.signTransaction(rawTx, accountFrom.privateKey);
        return this.web3.eth.sendSignedTransaction(signedTx.rawTransaction, function(err, hash) {
            if (err)
                throw(err);
            console.log("tx sendSignedTransaction hash:", hash);    
        });
    }
    
    async forceNewEpoch(accountFrom) {
        const turnLogsOff = true;
        console.log("forcing new epoch");
        const metadata = "0x"
        let currEpochRpcRes = await this.rpc.currentEpoch();
        const startEpoch = this.web3.utils.hexToNumber(currEpochRpcRes.result);
        let currentEpoch = startEpoch;
        console.log("current epoch (at the beginning)", currentEpoch);
        while (true) {
            await this.transactions.updateStakerMetadata(accountFrom, metadata, turnLogsOff);
            currEpochRpcRes = await this.rpc.currentEpoch();
            currentEpoch = this.web3.utils.hexToNumber(currEpochRpcRes.result);
            if (currentEpoch !== startEpoch) {
                console.log("current epoch (at the end)", currentEpoch);
                return;
            }
        }
    }

    async proxyImplementation(from) {
        return new Promise(resolve => {
            this.upgradabilityProxy.methods.implementation().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                } else {
                    console.log('getStakerId err', error);
                }
            });
        });
    }
    
    async updateContract(accountFrom, data) {
        console.log("prepare to updateContract");
        const nonce = await this.web3.eth.getTransactionCount(accountFrom.address);
        const gasPrice = await this.web3.eth.getGasPrice();
        const to = null;

        const rawTx = {
            from: accountFrom.address,
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce),
            data: data
        };

        let estimatedGas = await this.estimateGas(rawTx);
        rawTx.gasLimit = this.web3.utils.toHex(estimatedGas);
        let tx = await this.web3.eth.accounts.signTransaction(rawTx, accountFrom.privateKey);
        await this.web3.eth.sendSignedTransaction(tx.rawTransaction, (err, txHash) => {
            if (err) {
                console.log("updateContract err", err);
            }
        }); // txHash expected to be null. so we need to get last tx hash and read new contract address

        
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
}

module.exports.lachesis = lachesis;