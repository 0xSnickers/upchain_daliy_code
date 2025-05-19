import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'

export const viemClient = createPublicClient({
  chain: sepolia,
  transport: http(process.env.RPC_URL),
})
