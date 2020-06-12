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
    payer.address = `0x${config.payer.keyObject.address}`;
    payer.password = config.payer.password;
    payer.privateKey = config.payer.privateKey;

    let accounts = new AccountsHandler(web3, payer);    
    let lachesis = new lachesisContract.lachesis(web3, _sfc, contractAddress, upgradabilityProxy, null);


    let validator = await accounts.getPayer();
    let implementation = await lachesis.proxyImplementation(validator.address);
    console.log("implementation at start", implementation);
    const newContractAddress = await deploySfc(web3, payer.address);
    if (!newContractAddress)
        throw("no contract address found")

    await lachesis.unsignedUpgradeTo(validator, newContractAddress);
    implementation = await lachesis.proxyImplementation(validator.address);
    console.log("implementation at the end", implementation);
    return _sfc;
};

async function deploySfc(web3, from) {
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
    console.log(address);
    return address;
}


async function prepareSfc(web3) {
    const sfcContract = await updateContract(web3);
    return sfcContract;   
}

module.exports.deploySfc = prepareSfc;