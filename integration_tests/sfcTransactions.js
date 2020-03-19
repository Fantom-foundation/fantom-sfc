const EthUtil = require('ethereumjs-util');
const Tx = require('ethereumjs-tx').Transaction;
let fs = require("fs");
const Web3 = require('web3');
// var Tx = require('ethereumjs-tx');


class TransactionHandler {
    constructor(web3, sfc, contractAddr, txStorage) {
        this.web3 = web3;
        this.sfc = sfc;
        this.contractAddr = contractAddr;
        this.txStorage = txStorage;
    }

    advanceEpoch(from) {
        return this.newSignedTx({
            from: from,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.advanceEpoch().encodeABI(),
            gasLimit: 200000,
            web3Delegate: this.web3
        });
    };

    createDelegation(to, accountFrom, value) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: value,
            memo: this.sfc.methods.createDelegation(to).encodeABI(),
            gasLimit: 0
        });
    };

    getStakersNum(from) {
        return new Promise(resolve => {
            this.sfc.methods.stakersNum().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    };

    getStaker(from, stkrId) {
        return new Promise(resolve => {
            // console.log("this.sfc.methods.stakers", this.sfc.methods.stakers);
            this.sfc.methods.stakers(stkrId).call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    }; // delegations

    getDelegation(from, delegatorAddr) {
        return new Promise(resolve => {
            // console.log("this.sfc.methods.stakers", this.sfc.methods.stakers);
            this.sfc.methods.delegations(delegatorAddr).call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    }; // delegations

    stakeLockPeriodTime(from) {
        return new Promise(resolve => {
            // console.log("this.sfc.methods.stakers", this.sfc.methods.stakers);
            this.sfc.methods.stakeLockPeriodTime().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    }; 

    stakeLockPeriodEpochs(from) {
        return new Promise(resolve => {
            // console.log("this.sfc.methods.stakers", this.sfc.methods.stakers);
            this.sfc.methods.stakeLockPeriodEpochs().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('getStakersNum err', error);
                }
            });
        });
    };

    currentSealedEpoch(from) {
        return new Promise(resolve => {
            // console.log("this.sfc.methods.stakers", this.sfc.methods.stakers);
            this.sfc.methods.currentSealedEpoch().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                    return;
                } else {
                    console.log('currentSealedEpoch err', error);
                }
            });
        });
    };

    async updateStakerMetadata(accountFrom, metadata, turnLogsOff) {
            return this.newSignedTx({
                accountFrom: accountFrom,
                to: this.contractAddr,
                value: "0",
                memo: this.sfc.methods.updateStakerMetadata(metadata).encodeABI(),
                gasLimit: 0,
                turnLogsOff: turnLogsOff,
            });
    }

    async increaseStake(accountFrom, value) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: value,
            memo: this.sfc.methods.increaseStake().encodeABI(),
            gasLimit: 0
        });
    };

    async claimValidatorRewards(accountFrom, maxEpochs) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.claimValidatorRewards(maxEpochs).encodeABI(),
            gasLimit: 0
        });
    }

    async updateStakerSfcAddress(accountFrom, newAddress) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.updateStakerSfcAddress(newAddress).encodeABI(),
            gasLimit: 0
        });
    };

    async withdrawDelegation(accountFrom) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.withdrawDelegation().encodeABI(),
            gasLimit: 0
        });
    };

    async prepareToWithdrawDelegation(accountFrom) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.prepareToWithdrawDelegation().encodeABI(),
            web3Delegate: this.web3
        });    
    }; // claimDelegationRewards

    async claimDelegationRewards(accountFrom, maxEpochs) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.claimDelegationRewards(maxEpochs).encodeABI(),
            web3Delegate: this.web3
        });    
    };

    async upgradeStakerStorage(accountFrom, stakerId) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods._upgradeStakerStorage(stakerId).encodeABI(),
            web3Delegate: this.web3
        });
    };

    async prepareToWithdrawStake(accountFrom) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.prepareToWithdrawStake().encodeABI(),
            web3Delegate: this.web3
        });
    };

    async withdrawStake(accountFrom) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: "0",
            memo: this.sfc.methods.withdrawStake().encodeABI(),
            web3Delegate: this.web3
        });
    };

    stakersNum(from) {
        return new Promise(resolve => {
            this.sfc.methods.stakersNum().call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                } else {
                    console.log('stakersNum err', error);
                }
            });
        });
    };

    getStakerId(from, stakerAddr) {
        return new Promise(resolve => {
            this.sfc.methods.getStakerID(stakerAddr).call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                } else {
                    console.log('getStakerId err', error);
                }
            });
        });
    };

    sfcAddressToStakerID(from) {
        return new Promise(resolve => {
            console.log("from", from);
            this.sfc.methods.getStakerID(from).call({from}, function (error, result) {
                if (!error) {
                    resolve(result);
                } else {
                    console.log('sfcAddressToStakerID err', error);
                }
                
            });
        });
    }

        sfcAddressToStakerIDNew(from) {
            return new Promise(resolve => {
                console.log("from", from);
                this.sfc.methods._sfcAddressToStakerID(from).call({from}, function (error, result) {
                    if (!error) {
                        resolve(result);
                    } else {
                        console.log('sfcAddressToStakerID err', error);
                    }
                    
                });
            });
    };

    async createStake(accountFrom, value, metadata) {
        return this.newSignedTx({
            accountFrom: accountFrom,
            to: this.contractAddr,
            value: value,
            memo: this.sfc.methods.createStake(metadata).encodeABI(),
            web3Delegate: this.web3,
        });
    };

    // async createDelegation(addr, accountFrom, value, metadata) {
    //     return this.newSignedTx({
    //         accountFrom: accountFrom,
    //         to: this.contractAddr,
    //         value: value,
    //         memo: this.sfc.methods.createStakeWithAddresses(addr, addr, metadata).encodeABI(),
    //         web3Delegate: this.web3,
    //     });
    // };
    // const subscribedEvents = {}
    // Subscriber method
    subscribeLogEvent (contract, eventName) {
      const eventJsonInterface = this.web3.utils._.find(
        contract._jsonInterface,
        o => o.name === eventName && o.type === 'event',
      )
      const subscription = web3.eth.subscribe('logs', {
        address: contract.options.address,
        topics: [eventJsonInterface.signature]
      }, (error, result) => {
        if (!error) {
          const eventObj = web3.eth.abi.decodeLog(
            eventJsonInterface.inputs,
            result.data,
            result.topics.slice(1)
          )
          console.log(`New ${eventName}!`, eventObj)
        }
      })
      subscribedEvents[eventName] = subscription
    }


    // currently doesnt work. change or remove
    // returns new contract address
    async updateContract(from, data) {
        const nonce = await this.web3.eth.getTransactionCount(from);
        const gasPrice = await this.web3.eth.getGasPrice();
        const to = null;

        const rawTx = {
            from: from,
            gasPrice: this.web3.utils.toHex(gasPrice),
            nonce: this.web3.utils.toHex(nonce),
            data: data
        };

        let estimatedGas = await this.estimateGas(rawTx);
        console.log("estimatedGas", estimatedGas);
        rawTx.gasLimit = this.web3.utils.toHex(estimatedGas);
        await this.web3.eth.sendTransaction(rawTx, (err, txHash) => {
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



module.exports.TransactionHandler = TransactionHandler;
