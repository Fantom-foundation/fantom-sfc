const {lrcBin, govBin, propFacBin, dummySfcBin} = require('../compiled/bin');
const { propFacAbi } = require('../compiled/abi');
function prepareForTests() {
    //__$c510feaee45aaa3ba7ae37890885ad0550$__

}

let LrcAddress;

function linkGovBin() {
    let lrcHex = LrcAddress.replace('0x', '');
    const newGovBin = govBin.replace(/__\$c510feaee45aaa3ba7ae37890885ad0550\$__/g, lrcHex);
    return newGovBin;
}


async function deployDummySfc(web3, from) {
    const nonce = await web3.eth.getTransactionCount(from);
    const gasPrice = await web3.eth.getGasPrice();
    const to = null;

    const rawTx = {
        from: from,
        gasPrice: web3.utils.toHex(gasPrice),
        nonce: web3.utils.toHex(nonce),
        data: `0x${dummySfcBin}`
    };

    let estimatedGas = await estimateGas(rawTx, web3);
    rawTx.gasLimit = web3.utils.toHex(estimatedGas);
    let txHash;
    await web3.eth.sendTransaction(rawTx, (err, _txHash) => {
        if (err) {
            console.log("deploy DummySfc err", err);
        }
        txHash = _txHash;
        console.log(`DummySfc deployed. txHash: ${_txHash}`);
    });

    let receipt = await web3.eth.getTransactionReceipt(txHash);
    let address = receipt.contractAddress;
    console.log("DummySfc address:", address);
    LrcAddress = address;
    return address;
}

async function deployLrc(web3, from) {
    const nonce = await web3.eth.getTransactionCount(from);
    const gasPrice = await web3.eth.getGasPrice();
    const to = null;

    const rawTx = {
        from: from,
        gasPrice: web3.utils.toHex(gasPrice),
        nonce: web3.utils.toHex(nonce),
        data: `0x${lrcBin}`
    };

    let estimatedGas = await estimateGas(rawTx, web3);
    rawTx.gasLimit = web3.utils.toHex(estimatedGas);
    let txHash;
    await web3.eth.sendTransaction(rawTx, (err, _txHash) => {
        if (err) {
            console.log("deploy lrc err", err);
        }
        txHash = _txHash;
        console.log(`lrc deployed. txHash: ${_txHash}`);
    });

    let receipt = await web3.eth.getTransactionReceipt(txHash);
    let address = receipt.contractAddress;
    console.log("lrc address:", address);
    LrcAddress = address;
    return address;
}

async function estimateGas(rawTx, web3) {
    let estimateGas;
    await web3.eth.estimateGas(rawTx, (err, gas) => {
        if (err)
            throw(err);

        estimateGas = gas;
    });

    return estimateGas;
};

module.exports.deployLrc = deployLrc;
module.exports.linkGovBin = linkGovBin;
module.exports.deployDummySfc = deployDummySfc;