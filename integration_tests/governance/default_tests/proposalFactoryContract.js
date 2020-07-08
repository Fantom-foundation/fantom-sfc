const { propFacBin } = require('../compiled/bin');
const { propFacAbi } = require('../compiled/abi');

async function estimateGas(rawTx, web3) {
    let estimateGas;
    await web3.eth.estimateGas(rawTx, (err, gas) => {
        if (err)
            throw(err);

        estimateGas = gas;
    });

    return estimateGas;
};

class proposalFactoryContract {
    constructor(web3) {
        this.web3 = web3;
    }

    async init(from, proxyAddress) {
        await this.deploy(this.web3, from, proxyAddress);
        this.contractAbi = new this.web3.eth.Contract(propFacAbi, this.contractAddress);
    }

    async deploy(web3, from, proxyAddress) {
        const bin = `0x${propFacBin}`;
        const gasPrice = await web3.eth.getGasPrice();
        const proposalFactoryConstructor = new web3.eth.Contract(propFacAbi);
        const memo = proposalFactoryConstructor.deploy({
            data: bin,
            arguments: [proxyAddress] 
        }).encodeABI();
        const rawTx = {
            data: memo,
            from: from
        }
    
        let estimatedGas = await estimateGas(rawTx, web3);
        let txHash;
        await web3.eth.sendTransaction(rawTx, (err, _txHash) => {
            if (err) {
                console.log("deploy ProposalFactory err", err);
            }
            txHash = _txHash;
            console.log(`ProposalFactory deployed. txHash: ${txHash}`);
        });
        let receipt = await web3.eth.getTransactionReceipt(txHash);
        let address = receipt.contractAddress;
        console.log("ProposalFactory address:", address);
        this.contractAddress = address;
        return address;
    }

    async newSoftwareUpgradeProposal(from, proposalAddr) {
        const nonce = await this.web3.eth.getTransactionCount(from);
        const gasPrice = await this.web3.eth.getGasPrice();

        const txMsg = {
            from: from,
            to: this.contractAddress,
            value: "0",
            data: this.contractAbi.methods.newSoftwareUpgradeProposal(proposalAddr).encodeABI(),
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

        let receipt = await this.web3.eth.getTransactionReceipt(txHash);
        let receiptData = receipt.logs[0].data;
        let inputs = [{
            type: 'address',
            name: 'proposalAddress'
        }];
        let topics = ["0xf509e203a7fc622333a2d968aa68ad26931546c37225f09e8701b20bbe6f5def"];
        let decodeRes = this.web3.eth.abi.decodeLog(inputs, receiptData, topics);

        return decodeRes.proposalAddress;
    }
}

module.exports = proposalFactoryContract;