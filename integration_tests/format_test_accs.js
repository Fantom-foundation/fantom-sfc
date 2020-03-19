const fs = require("fs");

// it is assumed that test_accs.json from "go-lachesis/docker" are used.
// a json file must be served in a propper way.
// it doesnt work exactly well for now, needs to be updated
const pathToTestAccs = "./test_accs.json";
let file = fs.readFileSync(pathToTestAccs);
let str = file.toString();
let r = /,"0x(.*?)": /g;

let newStr = str
newStr = str.replace(r, str => {
    let x = "},{\"address\":" + str.slice(1, str.length-2) + ", \"props\": ";
    return x;
})

fs.writeFileSync('./accounts.json', newStr);

//solc_5.11 --bin-runtime --allow-paths ~/repos/work/solidity/fantom_sfc_v1.1/contracts/ownership/ --combined-json abi,asm,ast,bin,bin-runtime,devdoc,interface,opcodes,srcmap,srcmap-runtime,userdoc contracts/sfc/Staker.sol > contracts.json
