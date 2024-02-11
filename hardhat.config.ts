import { config as dotenvConfig } from "dotenv"
import { resolve } from "path"
import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-ethers"
import "@nomicfoundation/hardhat-verify"

import "./task"

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env"
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) })

const privateKey: string | undefined = process.env.PRIVATE_KEY
if (!privateKey) {
  throw new Error("Please set your PRIVATE_KEY in a .env file")
}

const config: HardhatUserConfig = {
  networks: {
    optimism: {
      accounts: [privateKey as string],
      chainId: 10,
      url: process.env.OPTIMISM_JSON_RPC_URL,
      gasPrice: 0.004e9,
    },
  },
  etherscan: {
    apiKey: {
      optimisticEthereum: process.env.OPTIMISM_API_KEY as string,
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.20",
    settings: {
      evmVersion: "paris",
      optimizer: {
        enabled: true,
        runs: 10000,
      },
    },
  },
  sourcify: {
    enabled: false,
  },
}

export default config
