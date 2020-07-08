const {
    BN,
    ether,
    expectRevert,
    time,
    balance,
} = require('openzeppelin-test-helpers');

advanceTimeAndBlock = async (time, web3) => {
    await advanceBlock(web3);
    await advanceTime(time, web3);
    await advanceBlock(web3);

    return Promise.resolve(web3.eth.getBlock('latest'));
}

advanceTime = (time, web3) => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [time],
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err); }
            return resolve(result);
        });
    });
}

advanceBlock = (web3) => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_mine",
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err); }
            // const newBlockHash = web3.eth.getBlock('latest').hash;

            return resolve(result)
        });
    });
}

class LrcOption {
    constructor() {
        this.opinions = [
            {id: new BN(0), count: new BN(0) },
            {id: new BN(1), count: new BN(0) },
            {id: new BN(2), count: new BN(0) },
            {id: new BN(3), count: new BN(0) },
            {id: new BN(5), count: new BN(0) }
        ];
        this.rawCount = new BN(0);
        this.arc = new BN(0);
        this.dw = new BN(0);
        this.resistance = new BN(0);
        this.totalVotes = new BN(0);
    }

    calculate() {
        for (let opinion of this.opinions) {
            let voteVal = opinion.id.mul(opinion.count);
            this.rawCount = this.rawCount.add(voteVal);
        }
        
        let five = new BN(5);
        let rebaseScale = new BN("10000");
        let maxRes = five.mul(this.totalVotes);
        let scaledRawCount = this.rawCount.mul(rebaseScale);
        this.arc = scaledRawCount.div(maxRes);
        this.dw = this.opinions[4].count.mul(rebaseScale).div(this.totalVotes);
    }
}

module.exports = {
    advanceTime,
    advanceBlock,
    advanceTimeAndBlock,
    LrcOption
}