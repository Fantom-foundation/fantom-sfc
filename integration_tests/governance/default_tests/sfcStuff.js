const {sfcBin} = require('../compiled/bin');
const {sfcAbi, upgradabilityProxyAbi} = require('../compiled/abi');
const lachesisContract = require('../../sfc/lachesis');
const {AccountsHandler} = require('../../sfc/testaccounts');
const {TransactionStorage} = require('../../sfc/transactionStorage');
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

async function updateContract(web3) {

    let contractAddress = config.defaultTestsConfig.sfcContractAddress;
    let _sfc = new web3.eth.Contract(sfcAbi, contractAddress); // abi
    let upgradabilityProxy = new web3.eth.Contract(upgradabilityProxyAbi, contractAddress);

    let payer = {};
    payer.address = config.payer.keyObject.address;
    payer.password = config.payer.password;
    payer.privateKey = config.payer.privateKey;

    let accounts = new AccountsHandler(web3, payer);    
    let lachesis = new lachesisContract.lachesis(web3, _sfc, contractAddress, upgradabilityProxy, null);


    let validator = await accounts.getPayer();
    let implementation = await lachesis.proxyImplementation(validator.address);
    console.log("implementation at start", implementation);
    let tx = await lachesis.updateContract(validator, `0x${sfcBin}`);
    if (tx != null && tx != undefined) {
        console.log("contract tx!!!!!!", tx)
    }

    let depth = 100;
    let lastTransactionsHashes = await lachesis.findLastTransaction(depth);
    if (!lastTransactionsHashes)
        throw('last tx hash is undefined');
    if (lastTransactionsHashes.length > 1)
        throw('cannot handle multiple transactions');

    let updateContractTxHash = lastTransactionsHashes[0];
    console.log("updateContract tx hash", updateContractTxHash);
    let updateContractTxReceipt = await lachesis.rpc.getTransactionReceipt(updateContractTxHash);
    console.log("updateContractTxReceipt", updateContractTxReceipt);
    const newContractAddress = updateContractTxReceipt.result.contractAddress;
    if (!newContractAddress)
        throw("no contract address found")

    await lachesis.upgradeTo(validator, newContractAddress);
    implementation = await lachesis.proxyImplementation(validator.address);
    console.log("implementation at the end", implementation);
};


async function deploySfc(web3, from) {
    updateContract(web3);
    return;
    const nonce = await web3.eth.getTransactionCount(from);
    const gasPrice = await web3.eth.getGasPrice();
    const to = null;

    const rawTx = {
        from: from,
        gasPrice: web3.utils.toHex(gasPrice),
        nonce: web3.utils.toHex(nonce),
        data: `0x${sfcBin}`
    };

    let estimatedGas = await estimateGas(rawTx, web3);
    rawTx.gasLimit = web3.utils.toHex(estimatedGas);
    let txHash;
    await web3.eth.sendTransaction(rawTx, (err, _txHash) => {
        if (err) {
            console.log("deploy sfc err", err);
        }
        txHash = _txHash;
        console.log(`sfc deployed. txHash: ${_txHash}`);
    });

    let receipt = await web3.eth.getTransactionReceipt(txHash);
    let address = receipt.contractAddress;
    return address;
}

module.exports.deploySfc = deploySfc;