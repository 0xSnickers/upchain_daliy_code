import { viemClient } from '../clients/viemClient'
import { toHex, decodeAbiParameters, keccak256, pad } from 'viem'


export interface LockInfo {
    user: `0x${string}`
    startTime: string
    amount: string
}

export async function getEthBalance(address: `0x${string}`) {
    const balance = await viemClient.getBalance({ address })
    return balance.toString()
}

/**
 * 获取 address 合约 _locks 结构体数组插槽数据
 * @param address 合约地址 (sepolia=0x8b1f7b359590b375deee61878c2238b8f003325e)
 * @param slot 插槽Index 
 * @returns 
 */
export async function getStorageAt(address: `0x${string}`, slot: number) {
    const baseSlot = toHex(slot) //  (slot=0, 需要传: 0x0)
    const lengthHex = await viemClient.getStorageAt({
        address: address,
        slot: baseSlot
    })
    if (!lengthHex) throw new Error('Storage slot is empty or not found')
    // 1. 解码获取 _locks 数组长度
    const [length] = decodeAbiParameters([{ type: 'uint256' }], lengthHex)

    // 2. 计算起始 slot: keccak256(pad(slot, 32))
    const dataStartSlot = BigInt(
        keccak256(pad(baseSlot, { size: 32 })) // 注意：slot 要 padding 成 32 字节再 keccak
    )

    const result: LockInfo[] = await _getLockInfoAt(address, length, dataStartSlot)

    return result
}



async function _getLockInfoAt(address: `0x${string}`, length: bigint, dataStartSlot: bigint): Promise<LockInfo[]> {
    const result: LockInfo[] = []
    for (let i = 0n; i < length; i++) {
        const base = dataStartSlot + i * 3n
        /**
         * 结构体：
         * struct LockInfo{
         *   address user;
         *   uint64 startTime; 
         *   uint256 amount;
         * }
         */
        const [userSlot, startSlot, amountSlot] = [
            toHex(base), // user
            toHex(base + 1n), // startTime
            toHex(base + 2n), // amount
        ] as [`0x${string}`, `0x${string}`, `0x${string}`]


        const userHex = await viemClient.getStorageAt({
            address,
            slot: userSlot,
        }
        )
        const startHex = await viemClient.getStorageAt({
            address,
            slot: startSlot,
        }
        )
        const amountHex = await viemClient.getStorageAt({
            address,
            slot: amountSlot,
        }
        )

        if (!userHex || !startHex || !amountHex) continue // skip if any is missing

        const [user] = decodeAbiParameters([{ type: 'address' }], userHex)
        const [startTime] = decodeAbiParameters([{ type: 'uint64' }], startHex)
        const [amount] = decodeAbiParameters([{ type: 'uint256' }], amountHex)

        result.push({ user, startTime: startTime.toString(), amount: amount.toString() })
    }
    console.log('result->>',result)
    return result
}