import { task } from "hardhat/config";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-solhint";
import "@nomiclabs/hardhat-etherscan";

const config = require("./config.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    bscTestnet: {
      // 97: [
      //   'https://data-seed-prebsc-1-s1.binance.org:8545',
      //   'https://data-seed-prebsc-2-s1.binance.org:8545',
      //   'https://data-seed-prebsc-1-s2.binance.org:8545',
      //   'https://data-seed-prebsc-2-s2.binance.org:8545',
      //   'https://data-seed-prebsc-1-s3.binance.org:8545',
      //   'https://data-seed-prebsc-2-s3.binance.org:8545',
      // ]
      gasLimit: "10000000",
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [config.privateKey]
    },
    bscMainnet: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: [config.privateKey]
    }
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 500000
  },
  etherscan: {
    apiKey: config.bscscanApiKey
  }
};

