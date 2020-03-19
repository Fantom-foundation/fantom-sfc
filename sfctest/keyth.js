var keythereum = require("keythereum-pure-js");
var datadir = "~/.lachesis/";
var address= "0x19eb4c98009be5d8bcbc07520fb1871a8e348674";
const password = "123456";
var datadir = "/home/masurk/.lachesis/fakenet-1/";
var keyObject = keythereum.importFromFile(address, datadir);
var pk1 = keythereum.recover(password, keyObject);
console.log("pk1", pk1)
keyObject = {"address":"95f30ec61da14a8b3abc24bb11eebcf58f9f0cf3","crypto":{"cipher":"aes-128-ctr","ciphertext":"30f6235d561c44538eb6c234b1e429c56a3650a3b04c4b0aa5905533d7c82922","cipherparams":{"iv":"4ab0baf8eef69a38b2f5069b4b0582c0"},"kdf":"scrypt","kdfparams":{"dklen":32,"n":262144,"p":1,"r":8,"salt":"a09cc7d83a86b42087e7cfe34566206daf5956f8cffee2803175739f2790cef3"},"mac":"f8b64f2824acc98f2e551de0e696717e5dcf55bedf105269c022bbf0281c82b5"},"id":"abbeda74-c324-4120-9d99-efa3236ead00","version":3};
var pk2 = keythereum.recover(password, keyObject);
console.log(privateKey.toString('hex'));
console.log("pk2", pk1)
//343ba3ed7da835da945f9cbd784e62e1c329737c1b33b262e38a53501021af44