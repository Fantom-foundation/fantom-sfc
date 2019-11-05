export default (() => {
    const mineBlock = () => (
        new Promise((resolve, reject) => web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_mine',
            id: new Date().getTime(),
        }, (error, result) => (error ? reject(error) : resolve(result.result))))
    );

    const addSeconds = (seconds) => (
        new Promise((resolve, reject) => web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [seconds],
            id: new Date().getTime(),
        }, (error, result) => (error ? reject(error) : resolve(result.result))))
            .then(mineBlock)
    );

    const addDays = (days) => addSeconds(days * 24 * 60 * 60);

    const currentTimestamp = () => (
        new web3.BigNumber(web3.eth.getBlock(web3.eth.blockNumber).timestamp)
    );

    function latestTime() {
        return web3.eth.getBlock('latest').timestamp;
    }
    function increaseTimeTo(target) {
        const now = latestTime();
        if (target < now) throw Error(`Cannot increase current time(${now}) to a moment in the past(${target})`);
        const diff = target - now;
        return addSeconds(diff);
    }


    return {
        addSeconds,
        addDays,
        currentTimestamp,
        increaseTimeTo,
        latestTime,
    };
})();
