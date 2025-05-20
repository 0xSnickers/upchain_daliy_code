import MY_TOKEN_JSON from '@/abi/MyToken.json'
import TOKEN_BANK_JSON from '@/abi/TokenBank.json'
import NFT_MARKET_JSON from '@/abi/NFTMarket.json'

/**
 * @desc BASE_ERC721_JSON = 当前使用的 ERC721 NFT 合约
 * 每个 NFT 合约具备的功能不同
 * BASE_ERC721_JSON = ERC721WithSignature | MyERC721Enumerable | BaseERC721
 */
import ERC721_JSON from '@/abi/ERC721WithSignature.json'
// import { mainnet, sepolia } from 'viem/chains'
import { sepolia as sepoliaChain } from 'viem/chains'
import { Chain } from 'viem'
import { http, createConfig } from 'wagmi'
import { walletConnect } from 'wagmi/connectors'
// import { createWeb3Modal } from '@web3modal/wagmi/react'

// 自定义 Sepolia RPC 节点列表
const SEPOLIA_RPC_URLS = {
  // 默认节点
  default: 'https://sepolia.drpc.org',
  // 备用节点
  infura: import.meta.env.VITE_SEPOLIA_INFURA_RPC_URL,
  local: 'http://127.0.0.1:8545',
}
// 创建自定义的 Anvil 链配置
export const anvil = {
  id: 31337,
  name: 'Anvil',
  network: 'anvil',
  nativeCurrency: {
    decimals: 18,
    name: 'Ethereum',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] },
  },
  blockExplorers: {
    default: { name: 'Anvil', url: '' },
  },
  testnet: true,
} as const

// 创建自定义 Sepolia 配置
export const sepolia: Chain = {
  ...sepoliaChain,
  rpcUrls: {
    ...sepoliaChain.rpcUrls,
    default: {
      http: [SEPOLIA_RPC_URLS.infura],
      // http: [SEPOLIA_RPC_URLS.local],
    },
    public: {
      http: [
        // SEPOLIA_RPC_URLS.local,
        SEPOLIA_RPC_URLS.infura,
        // SEPOLIA_RPC_URLS.default,
      ],
    },
  },
}
// const rpc_url = "https://sepolia.infura.io/v3/57255eaeb40541068e78f34831a5fc1a"


// 合约地址配置
export const CONTRACT_ADDRESSES = {
  [anvil.id]: {
    TOKEN_BANK: '0x4D34f0c563d09DAC60B7E12dDBAaDE86aBd47014',
    MYTOKEN: '0xF22fFe4336a074491890A5CE4113dCfc37B61Ebe',
    BASE_ERC721: '0x2d97BBC4B7d5b2c50C810d6539cb339D37Ad2AF6',
    NFT_MARKET: '0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E',
    PERMIT_TOKEN: '0x03e86E790524019B23E7B4c6fdE3565eD46Ca55d',
    PERMIT_TOKEN_BANK: '0xA31b47233c05cC343Ca1Ea0A2F40653982BFe8CD',
    TOKEN_BANK_WITH_ERC20TOKEN: '0x24c35b20faF55999735b3fA496F0d4F150771Bc5',
  },
  [sepolia.id]: {
    TOKEN_BANK: '0x4D34f0c563d09DAC60B7E12dDBAaDE86aBd47014',
    MYTOKEN: '0xF22fFe4336a074491890A5CE4113dCfc37B61Ebe',
    BASE_ERC721: '0x2d97BBC4B7d5b2c50C810d6539cb339D37Ad2AF6',
    NFT_MARKET: '0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E',
    PERMIT_TOKEN: '0x03e86E790524019B23E7B4c6fdE3565eD46Ca55d',
    PERMIT_TOKEN_BANK: '0xA31b47233c05cC343Ca1Ea0A2F40653982BFe8CD',
    TOKEN_BANK_WITH_ERC20TOKEN: '0x24c35b20faF55999735b3fA496F0d4F150771Bc5',
  },
} as const

// 获取当前网络的合约地址
export const getContractAddresses = (chainId: number) => {
  return CONTRACT_ADDRESSES[chainId as keyof typeof CONTRACT_ADDRESSES] || CONTRACT_ADDRESSES[anvil.id]
}

// 导出合约地址
export const TOKEN_BANK_ADDRESS = getContractAddresses(sepolia.id).TOKEN_BANK as `0x${string}`
export const MYTOKEN_ADDRESS = getContractAddresses(sepolia.id).MYTOKEN as `0x${string}`
export const BASE_ERC721_ADDRESS = getContractAddresses(sepolia.id).BASE_ERC721 as `0x${string}`
export const NFT_MARKET_ADDRESS = getContractAddresses(sepolia.id).NFT_MARKET as `0x${string}`
export const PERMIT_TOKEN = getContractAddresses(sepolia.id).PERMIT_TOKEN as `0x${string}`
export const PERMIT_TOKEN_BANK = getContractAddresses(sepolia.id).PERMIT_TOKEN_BANK as `0x${string}`

// abi json
export const MY_TOKEN_ABI = MY_TOKEN_JSON
export const TOKEN_BANK_ABI = TOKEN_BANK_JSON 
export const NFT_MARKET_ABI = NFT_MARKET_JSON 
export const ERC721_NFT_ABI = ERC721_JSON 

// WalletConnect Project ID - 从 https://cloud.walletconnect.com/ 获取
export const projectId = import.meta.env.VITE_WC_PROJECT_ID
console.log('projectId->',projectId);

const chains = [
  // anvil,
  sepolia] as const

export const config = createConfig({
  chains,
  connectors: [
    // walletConnect({
    //   projectId,
    //   showQrModal: true,
    // }),
  ],
  transports: {
    // [anvil.id]: http(),
    [sepolia.id]: http(),
  },
})

// 创建 Web3Modal
// createWeb3Modal({
//   wagmiConfig: config,
//   projectId,
//   themeMode: 'light',
//   enableAnalytics: false,
// })
 