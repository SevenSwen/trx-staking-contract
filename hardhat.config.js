require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-etherscan');
require('dotenv').config();
require('solidity-coverage');
const { MAINNET, TESTNET, MNEMONIC, KEY } = process.env;

module.exports = {
    solidity: "0.8.6",
    networks: {
        hardhat: {
            forking: {
                url: MAINNET,
                blockNumber: 19253300
            }
        }
    },
    etherscan: {
        apiKey: KEY
    },
};
