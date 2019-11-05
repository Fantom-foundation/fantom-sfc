export const assertExpectedError = async (promise) => {
    try {
        await promise;
        throw new Error('Should have failed but did not!');
    } catch (error) {
        assert.isTrue(error.message.indexOf('invalid opcode') >= 0, `Unexpected error message: ${error.message}`);
    }
};

export const assertEvent = async (event, predicate) => new Promise((resolve, reject) => {
    event({}, { fromBlock: 0, toBlock: 'latest' }).get((error, logs) => {
        try {
            assert.isOk(logs, `No event logs found, error: ${error}`);
            const actualEvents = logs.filter(predicate);
            assert.equal(actualEvents.length, 1, 'No event found');
            resolve();
        } catch (e) {
            reject(e);
        }
    });
});

export const assertTransferEvent = async (contract, from, to, amount) => {
    const predicate = ({ args }) => args.from === from && args.to === to && args.value.eq(amount);
    await assertEvent(contract.Transfer, predicate);
};

export const assertEqual = (a, b) => assert.isTrue(Object.is(a, b), `Expected ${a.toString()} to equal ${b.toString()}`);
export const assertNotEqual = (a, b) => assert.isFalse(Object.is(a, b), `Expected ${a.toString()} to not equal ${b.toString()}`);
export const assertTrue = (a) => assert.isTrue(a, 'Mismatch');
export const assertFalse = (a) => assert.isFalse(a, 'Mismatch');
