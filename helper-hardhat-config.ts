export interface networkConfigItem {
    blockConfirmations?: number
  }
  
  export interface networkConfigInfo {
    [key: string]: networkConfigItem
  }
  
  export const networkConfig: networkConfigInfo = {
    localhost: {},
    hardhat: {},
    kovan: {
      blockConfirmations: 6,
    },
    rinkeby: {
        blockConfirmations: 1,
    },
  }
  
  export const developmentChains = ["hardhat", "localhost"]