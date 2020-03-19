
// holds occured transactions
class TransactionStorage {
    constructor() {
        this.transactionHashes = [];
    }

    saveTxHash(hash, name) {
        const tx = {hash:hash, name:name};
        this.transactionHashes.push(tx);
    }
}

module.exports.TransactionStorage = TransactionStorage;