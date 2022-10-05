import "@typechain/hardhat"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-ethers"
import "hardhat-gas-reporter"
import "dotenv/config"
import "solidity-coverage"
import "hardhat-deploy"
import "solidity-coverage"
import { HardhatUserConfig } from "hardhat/config"

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || "https://goerli.alchemyapi.io/v2/your-api-key"

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0000000000000000000000000000000000000000000000000000000000000000"

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""

const config: HardhatUserConfig = {
  defaultNetwork: "goerli",
  networks: {
    hardhat: {
      chainId: 31337,
      blockGasLimit: 20000000,
      gasPrice: 0,
      initialBaseFeePerGas: 0,
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: 'explain tackle mirror kit van hammer degree position ginger unfair soup bonus',
        count: 20,
        accountsBalance: '100000000000000000000000',
      }
    },
    goerli: {
        url: GOERLI_RPC_URL,
        accounts: [PRIVATE_KEY],
        chainId: 5,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
    ],
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
      5: 3 // goerli
    },
  },
}

export default config
