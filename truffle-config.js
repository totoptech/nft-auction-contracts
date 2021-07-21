require("dotenv").config();
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 7545,
            network_id: "5777",
        },
        rinkeby: {
            provider: () =>
                new HDWalletProvider(
                    process.env.RINKEBY_PK,
                    process.env.RINKEBY_PROVIDER
                ),
            network_id: 4,
            gas: 7000000,
        },
        ropsten: {
            provider: () =>
                new HDWalletProvider(
                    process.env.ROPSTEN_PK,
                    process.env.ROPSTEN_PROVIDER
                ),
            network_id: 3,
            gas: 7000000,
        },
    },

    // Set default mocha options here, use special reporters etc.
    mocha: {
        // timeout: 100000
    },

    compilers: {
        solc: {
            version: "0.7.4", // Fetch exact version from solc-bin (default: truffle's version)
            //docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
            /*settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
        //  evmVersion: "byzantium"
      },*/
        },
    },

    // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
    //
    // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
    // those previously migrated contracts available in the .db directory, you will need to run the following:
    // $ truffle migrate --reset --compile-all

    db: {
        enabled: false,
    },
};
