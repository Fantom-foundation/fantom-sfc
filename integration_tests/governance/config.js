const config = {
    defaultTestsConfig: {
        defaultHost: "localhost",
        defaultPort: "18545",
        defaultContractAddress: '0xfc00face00000000000000000000000000000000',
        sfcContractAddress: '0xfc00face00000000000000000000000000000000'
    },
    payer: {
        keyObject: {
            "address": "239fa7623354ec26520de878b52f13fe84b06971",
            "crypto": {
              "cipher": "aes-128-ctr",
              "ciphertext": "295f18a456b2d1acc3c6b84b55bec688908d1388b8c289d2f6f880738c6d4efe",
              "cipherparams": {
                "iv": "6df2b5db07ac185a439118658eba5fbd"
              },
              "kdf": "scrypt",
              "kdfparams": {
                "dklen": 32,
                "n": 262144,
                "p": 1,
                "r": 8,
                "salt": "c8315bc1019a24e94330211c4d02e1f44b617540d444b4cc6adbe3e9760fa3b0"
              },
              "mac": "12181dec816d68534563f76b7e2b57fb85022f4093a33547cabaa740774108fc"
            },
            "id": "18d0ce62-baa7-4cf9-b73d-b128bfbf813f",
            "version": 3
          },
        privateKey: "163f5f0f9a621d72fedd85ffca3d08d131ab4e812181e0d30ffd1c885d20aac7",
        password: "fakepassword"
    }
}

module.exports = config;