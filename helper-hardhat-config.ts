export interface networkConfigItem {
  blockConfirmations?: number
}

export interface networkConfigInfo {
  [key: string]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
  localhost: {},
  hardhat: {},
}

export const developmentChains = ["hardhat", "localhost"]