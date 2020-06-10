const {deploySfc} = require('./sfcStuff');
const {deployLrc, linkGovBin} = require('./preDeployment');
const GovContract = require('./governanceContract');
const Web3 = require('web3');
const config = require('../config');

const endpoint = `http://${config.defaultTestsConfig.defaultHost}:${config.defaultTestsConfig.defaultPort}`;

async function runTests() {
    try {
        const web3 = new Web3(new Web3.providers.HttpProvider(endpoint));

        const govContract = new GovContract(web3);
        await govContract.init();
        
        const coinbase = await govContract.accountHandler.getCoinbase();
        await deploySfc(web3, coinbase);
        await deployLrc(web3, coinbase);
    
        const govBin = linkGovBin();
        await govContract.deploy(govBin, coinbase);
        
        console.log('works');
    }
    catch(e) {
        console.log(`runTests error:\n${e}`)
    }
}

async function deployBins() {

}

module.exports = runTests;