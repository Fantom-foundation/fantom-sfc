const {DefaultTests} = require('./defaultTests');
const Web3 = require('web3');
const commander = require('commander');
const keythereum = require("keythereum-pure-js");
const config = require('./config');
const program = new commander.Command();

program
  .option('-l, --logs', 'output logs') // will be implemented or removed in a future updates
  .option('-h, --host <type>', 'rpc host. if not set localhost is used')
  .option('-p, --port <type>', 'rpc port. if not set 18545 is used')
  .option('-pr, --payer', 'use payer from config')
  .option('-i, --incomplete', 'runs incomplete test cases for a more fast execution. doesnt work in a current version')
  .option('-uaj, --useAccountsJson', 'not implemented yet')
  .option('-c, --contractAddress <type>', 'sets contract address. if not set 0xfc00face00000000000000000000000000000000 is used')
  .option('-b, --before run special "before updetes" tests', 'desc')
  .option('-a, --after', 'run special "after updetes" tests')
  .option('-u, --update run special "after updetes" tests', 'desc')
  .option('-o, --keyObject <type>', 'payer key object, use only with command --payer')
  .option('-w, --password <type>', 'payer password, use only with command --payer');

program.parse(process.argv);

const defaultHost = "localhost";
const defaultPort = "18545";
const defaultContractAddress = '0xfc00face00000000000000000000000000000000';
let host = program.host ? program.host : defaultHost;
let port = program.port ? program.port : defaultPort;
let endpoint = "http://" + host + ":" + port;
let contractAddress = program.contractAddress ? program.contractAddress : defaultContractAddress;

let payer;
if (program.payer) {
    if (program.keyObject && program.password) {
        let keyObject = JSON.parse(program.keyObject);
        payer = {
            keyObject: keyObject,
            privateKey: keythereum.recover(program.password.toString(), keyObject).toString('hex'),
            address: `0x${keyObject.address}`,
        };
    } else {
        payer = config.payer;
    }

}

console.log('payer:', payer)
const testHandler = new DefaultTests(endpoint, contractAddress, payer)


// if (program.incomplete) {
//     testHandler.incompleteTests()
// } else {
//     testHandler.runTests();
// }

testHandler.basicTests()
// testHandler.createStakersAndDelegations()
//         web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
// testHandler.withdrawStakerNew(web3.eth.accounts.create())
// testHandler.createAndWithdrawDelegation();
// testHandler.createStakesAndPrepareToWithdraw(2, 1);
// if (program.before) {
//     testHandler.testsBeforeUpdateOnly();
//     return;
// }

// if (program.after) {
//     testHandler.testsAfterUpdateOnly();
//     return;
// }
// console.log("no flags start is not supported in a current version");
