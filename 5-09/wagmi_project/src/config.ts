import MY_TOKEN_JSON from '@/abi/MyToken.json'
import TOKEN_BANK_JSON from '@/abi/TokenBank.json'
// import { mainnet, sepolia } from 'viem/chains'
import { sepolia as sepoliaChain } from 'viem/chains'
import { Chain } from 'viem'

// 自定义 Sepolia RPC 节点列表
const SEPOLIA_RPC_URLS = {
  // 默认节点
  default: 'https://sepolia.drpc.org',
  // 备用节点
  infura: 'https://sepolia.infura.io/v3/57255eaeb40541068e78f34831a5fc1a',
}
// wss://sepolia.infura.io/ws/v3/57255eaeb40541068e78f34831a5fc1a
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
    },
    public: {
      http: [
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
    TOKEN_BANK: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    MYTOKEN: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  },
  [sepolia.id]: {
    TOKEN_BANK: '0xCa1b0083bc23E67A170dF7609c7CD77736D8b52D', // 需要替换为 Sepolia 上的实际地址
    MYTOKEN: '0x21059fD1dF5ff7e53F035B0Abc320c6459A30DF5',    // 需要替换为 Sepolia 上的实际地址
  },
} as const

// 获取当前网络的合约地址
export const getContractAddresses = (chainId: number) => {
  return CONTRACT_ADDRESSES[chainId as keyof typeof CONTRACT_ADDRESSES] || CONTRACT_ADDRESSES[anvil.id]
}

// 导出合约地址
export const TOKEN_BANK_ADDRESS = getContractAddresses(anvil.id).TOKEN_BANK as `0x${string}`
export const MYTOKEN_ADDRESS = getContractAddresses(anvil.id).MYTOKEN as `0x${string}`

// abi json
export const MY_TOKEN_ABI = MY_TOKEN_JSON
export const TOKEN_BANK_ABI = TOKEN_BANK_JSON 