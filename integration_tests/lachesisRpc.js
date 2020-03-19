const axios = require('axios');

class rpc {
    async lachesis() {
        let res = await axios(this.post_config({"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":67}));
        console.log(res.data);
        /*
           { jsonrpc: '2.0',
             id: 57,
             result: 'go-lachesis/v1.9.8-stable/linux-amd64/go1.13.3' }
        */

        res = await axios(this.post_config({"jsonrpc":"2.0","method":"net_version","params":[],"id":67}));
        console.log(res.data);

        res = await axios(this.post_config({"jsonrpc":"2.0","method":"eth_getBalance","params":["0x7f9d1dbaf84d827b0840e38f555a490969978d20", "latest"],"id":1}));
        console.log(res.data);


        res = await axios(this.post_config({"jsonrpc":"2.0","method":"eth_sendRawTransaction","params":["0xf865808609184e72a00082271094d6a37423be930019b8cfea57be049329f3119a3d800026a022ee12db5a53b2a43d79c3d5b30f26287817a785da4be80b85ea368c746b2e0fa06e7178582d58eb80e407062c4afc4f4634e2908ef1b874f36b93b94093902f66"],"id":1}));
        console.log(res.data)
    }

    async getTxPoolContent() {
        let req = {"jsonrpc":"2.0","method":"txpool_content","params":[],"id":1};
        let res = await axios(this.post_config(req));
        return res;
    }

    async getLatestBlock() {
        let req = {"jsonrpc":"2.0","method":"ftm_getBlockByNumber","params":["latest", false],"id":1};
        let res = await axios(this.post_config(req));
        return res;
    }
    
    async getBlockByNumber(num) {
        let req = {"jsonrpc":"2.0","method":"ftm_getBlockByNumber","params":[num.toString(), false],"id":1};
        let res = await axios(this.post_config(req));
        return res;
    }

    async coinbase() {
        const req = {"jsonrpc":"2.0","method":"eth_coinbase","id":1};
        const res = await axios(this.post_config(req));
        if (res.data && res.data.error) {
            console.log("request error:", res.data.error);
        }
        return res.data.result;
    }

    async currentEpoch() {
        const req = `{"jsonrpc":"2.0","method":"ftm_currentEpoch","id":1}`
        const res = await axios(this.post_config(req));
        return res.data
    }

    async getTransactionReceipt(hash) {
        const req = {
            "jsonrpc":"2.0",
            "method":"ftm_getTransactionReceipt", 
            "params":[hash],
            "id":1
        };
        const res = await axios(this.post_config(req));
        return res.data;
    }

    post_config(data) {
        return {
            method: 'post',
            url: 'http://localhost:18545/',
            data: data,
            headers: {'content-type':'application/json'}
        }
    }
}

module.exports.rpc = rpc;
