import { http } from 'viem'
import { createConfig } from 'wagmi'
// import { mainnet, sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'
import { sepolia } from '@/config'

// 本地 Foundry Anvil 开发链
const localhost = {
  id: 31337,
  name: 'Localhost',
  network: 'localhost',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] },
  },
}

export const config = createConfig({
  chains: [sepolia ,localhost],
  connectors: [injected()],
  transports: {
    [sepolia.id]: http(),
    [localhost.id]: http(),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}
