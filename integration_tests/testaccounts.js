var fs = require("fs");
const Tx = require('ethereumjs-tx').Transaction;

class AccountsHandler {
    constructor(web3, payer) {
        var file = fs.readFileSync("./accounts.json")
        this.savedAccs = JSON.parse(file.toString());
        this.web3 = web3;
        this.validatorUnlocked = false;
        this.createdAccs = [];
        if (payer)
            this.payer = payer;
        // this.usedAddresses
        
        // console.log("json savedAccs", this.savedAccs.length)
        this.lastCalledId = 0;
    }

    getNextAccount() {
        const newAcc = this.savedAccs[this.lastCalledId];
        newAcc.id = this.lastCalledId;
        this.lastCalledId++;
        return newAcc;
    }

    getAccountAtId(id) {
        return this.savedAccs[id];
    }

    async getNewAccount() {
        return this.web3.eth.accounts.create();
    }

    // sender is an account that will send founds to a new acc
    async createAccountWithBalance(sender, value) {
        let newAcc = await this.getNewAccount();

        let gasPrice = 2; // or get with web3.eth.gasPrice
        let gasLimit = 3000000; // temp. add estimate later
        let from = sender.address;
        let nonce = await this.web3.eth.getTransactionCount(from);
        let toAddress = newAcc.address;
        console.log("toAddress", toAddress);
        let chainId = await this.web3.eth.net.getId();
        console.log("chainId", chainId);
        console.log("typeof chainId", typeof chainId);

        let rawTx = {
          from: from,
          nonce: this.web3.utils.toHex(nonce),
          gasPrice: this.web3.utils.toHex(gasPrice * 1e9),
          gasLimit: this.web3.utils.toHex(gasLimit),
          to: toAddress,
          value: this.web3.utils.toHex(this.web3.utils.toWei(value, 'ether')),
          chainId: chainId //remember to change this
        };
        
        let tx = await this.web3.eth.accounts.signTransaction(rawTx, sender.privateKey);
        await this.web3.eth.sendSignedTransaction(tx.rawTransaction, function(err, hash) {
            if (err)
                throw(err);
            console.log("tx createAccountWithBalance hash:", hash);    
        });
      
        return newAcc;
    }

    async unlockAccount(addr, pass) {
        // console.log("this.web3.personal", this.web3.personal);
        // console.log("this.web3.unlockAccount", this.web3.unlockAccount);
        await this.web3.eth.personal.unlockAccount(addr, pass);
        // console.log("this.web3.personal", this.web3.personal.unlockAccount);
        
    }

    async getValidator() {
        const privKey = "163f5f0f9a621d72fedd85ffca3d08d131ab4e812181e0d30ffd1c885d20aac7"; // 0x163f5f0f9a621d72fedd85ffca3d08d131ab4e812181e0d30ffd1c885d20aac7
        const pass = "fakepassword"
        const addr = "0x239fa7623354ec26520de878b52f13fe84b06971";//0x239fA7623354eC26520dE878B52f13Fe84b06971

        if (!this.validatorUnlocked) {
            await this.unlockAccount(addr, pass);
            this.validatorUnlocked = true;
        }
        // var mainStaker;
        // var accs = await web3.eth.getAccounts();
        // mainStaker = accs[0];

        // var keythereum = require("keythereum");
        // var datadir = "~/.lachesis/";
        // var address= "0x19eb4c98009be5d8bcbc07520fb1871a8e348674";
        // const password = "fakepass";

        // var keyObject = keythereum.importFromFile(address, datadir);
        // var privateKey = keythereum.recover(password, keyObject);
        // console.log(privateKey.toString('hex'));
        return {privateKey: privKey, address: addr}
    }

    // todo: make not constant
    async getPayer() {
        if (this.payer)
            return this.payer;
        return this.getValidator();
    }

    async getCoinbase() {
        let cb;
        await web3.eth.getCoinbase((err, coinbase) => {
            cb = coinbase;
        });
        return cb;
    }
}

module.exports.AccountsHandler = AccountsHandler;