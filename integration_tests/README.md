### How to start local tests
Clone this repository and run ```npm install```   
Then run fakenet lachesis node with rpc turned on:   
```bash
./build/lachesis --fakenet=1/1 --rpc --rpcapi="eth,debug,admin,web3,personal,net,txpool,ftm,sfc"
```
Now you can run local tests with:   
```bash
node testing.js
```

If a host/port of your rpc is not default, you can specify it with flags ```-h``` and ```-p``` respectively:   
```bash
node testing.js -h "127.0.0.1" -p 18545
```
You can also set a contract address manualy with ```-c``` flag   
If you run lachesis with a single validator, you will probably also need to increase default stake value in code (for testing purpose).   
You can find it inside go-lachesis/cmd/lachesis/fake.go. For example:   
```golang
vaccs = genesis.FakeValidators(validatorsNum, utils.ToFtm(1e10), utils.ToFtm(3175000 * 10))
```   

You can also reduce cfg.MaxEpochBlocks value, this will speed testing up (variable is placed inside /go-lachesis/lachesis/config.go file, FakeNetDagConfig func). For example you can set it to 20 blocks.   
```golang
cfg.MaxEpochBlocks = 20
```   
### How to start staging testing
A staging testing cases run via RPC calls, so you have to make sure that "--rpc" flag is passed to an app and that all namespaces are turned on (you can just use an example above with --rpc --rpcapi="eth,debug,admin,web3,personal,net,txpool,ftm,sfc" flags).   
If rpc is turned on and nodes are running, it is possible to start testing.   
To run tests properly, you will have to provide a payer - an account with a huge amount of available resources. A payer should be defined inside config.json. You can try to use a default config.json with a default payer for a staging testing, as it doesn't change realy often.
To run tests with a payer you just have to provide "--payer" flag, and a payer info will be taken from config.   

```bash
node testing.js --payer
```

If you need to use a custom payer, use additional parameters: `--keyObject` (located in file in the `keystore` folder in `data_dir`) and `--password` along with `--payer` flag

```bash
keyObject='{"address":"95f30ec61da14a8b3abc24bb11eebcf58f9f0cf3","crypto":{"cipher":"aes-128-ctr","ciphertext":"30f6235d561c44538eb6c234b1e429c56a3650a3b04c4b0aa5905533d7c82922","cipherparams":{"iv":"4ab0baf8eef69a38b2f5069b4b0582c0"},"kdf":"scrypt","kdfparams":{"dklen":32,"n":262144,"p":1,"r":8,"salt":"a09cc7d83a86b42087e7cfe34566206daf5956f8cffee2803175739f2790cef3"},"mac":"f8b64f2824acc98f2e551de0e696717e5dcf55bedf105269c022bbf0281c82b5"},"id":"abbeda74-c324-4120-9d99-efa3236ead00", "version":3}'

node testing.js -h "127.0.0.1" -p 18545 --payer --keyObject $keyObject  --password 123456
```
