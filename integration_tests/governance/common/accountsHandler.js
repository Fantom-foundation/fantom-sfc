const config = require('../config');

class AccountsHandler {
    constructor(web3) {
        this.web3 = web3;
        this.validatorUnlocked = false;
        this.createdAccs = [];
        this.payer = config.payer;
        this.lastCalledId = 0;
    }

    async init() {
        // this.web3.personal.importRawKey(this.payer.privateKey, this.payer.password);
        try {
            await this.unlockAccount(this.payer.keyObject.address, this.payer.password);
        }
        catch(e) {
            console.log(e)
        }
    }

    async getNewAccount() {
        return this.web3.eth.accounts.create();
    }

    // sender is an account that will send founds to a new acc
    async createAccountWithBalance(sender, value, unsigned) {
        let newAcc = await this.getNewAccount();

        let gasPrice = 2; // or get with web3.eth.gasPrice
        let gasLimit = 3000000; // temp. add estimate later
        let from = sender.address;
        let nonce = await this.web3.eth.getTransactionCount(from);
        let toAddress = newAcc.address;
        let chainId = await this.web3.eth.net.getId();

        let rawTx = {
          from: from,
          nonce: this.web3.utils.toHex(nonce),
          gasPrice: this.web3.utils.toHex(gasPrice * 1e9),
          gasLimit: this.web3.utils.toHex(gasLimit),
          to: toAddress,
          value: this.web3.utils.toHex(this.web3.utils.toWei(value, 'ether')),
          chainId: chainId //remember to change this
        };

        if (unsigned) {
            await this.web3.eth.sendTransaction(rawTx, function(err, hash) {
                if (err)
                    throw(err);
                console.log("tx createAccountWithBalance hash:", hash);  
            });
            return newAcc;
        }
        
        let tx = await this.web3.eth.accounts.signTransaction(rawTx, sender.privateKey);
        await this.web3.eth.sendSignedTransaction(tx.rawTransaction, function(err, hash) {
            if (err)
                throw(err);
            console.log("tx createAccountWithBalance hash:", hash);    
        });
      
        return newAcc;
    }

    async unlockAccount(addr, pass) {
        await this.web3.eth.personal.unlockAccount(addr, pass);        
    }

    // todo: make not constant
    async getPayer() {
        if (this.payer)
            return this.payer;
        return this.getValidator();
    }

    async getCoinbase() {
        let cb;
        await this.web3.eth.getCoinbase((err, coinbase) => {
            cb = coinbase;
        });
        return cb;
    }
}

module.exports = AccountsHandler;