export const ether = (n) => new web3.BigNumber(web3.toWei(n, 'ether'));

export const oneEther = ether(1);

export const transaction = (address, wei) => ({
    from: address,
    value: wei,
});

export const ethBalance = (address) => web3.eth.getBalance(address);
