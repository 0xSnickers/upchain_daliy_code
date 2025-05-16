import { useAccount, useReadContract, useWriteContract, useSignTypedData, useChainId } from 'wagmi'
import { parseEther } from 'viem'
import { useState, useEffect } from 'react'
import { Input, Button, Card, message, Space, Typography } from 'antd'
import PermitTokenABI from '@/abi/PermitToken.json'
import PermitTokenBankABI from '@/abi/PermitTokenBank.json'
import { PERMIT_TOKEN, PERMIT_TOKEN_BANK } from '@/config'

const { Text } = Typography

function PermitTokenBank() {
    const { address } = useAccount()
    const chainId = useChainId()
    const [amount, setAmount] = useState('')
    const [loading, setLoading] = useState(false)
    const [isValidAddresses, setIsValidAddresses] = useState(false)

    // Validate contract addresses
    useEffect(() => {
        if (!PERMIT_TOKEN || !PERMIT_TOKEN_BANK) {
            console.error('Contract addresses are not defined')
            message.error('Contract addresses are not configured')
            setIsValidAddresses(false)
            return
        }

        if (!PERMIT_TOKEN.startsWith('0x') || !PERMIT_TOKEN_BANK.startsWith('0x')) {
            console.error('Invalid contract addresses format')
            message.error('Invalid contract addresses format')
            setIsValidAddresses(false)
            return
        }

        setIsValidAddresses(true)
    }, [chainId])

    // Read token nonce
    const { data: nonce, refetch: refetchNonce } = useReadContract({
        address: isValidAddresses ? (PERMIT_TOKEN as `0x${string}`) : undefined,
        abi: PermitTokenABI,
        functionName: 'nonces',
        args: [address],
    })

    // Read domain separator
    const { data: domainSeparator } = useReadContract({
        address: PERMIT_TOKEN as `0x${string}`,
        abi: PermitTokenABI,
        functionName: 'DOMAIN_SEPARATOR',
    })
    console.log('Contract Domain Separator:', domainSeparator)

    // Read token balance
    const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
        address: isValidAddresses && address ? (PERMIT_TOKEN as `0x${string}`) : undefined,
        abi: PermitTokenABI,
        functionName: 'balanceOf',
        args: [address],
    })

    // Read bank balance
    const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
        address: isValidAddresses && address ? (PERMIT_TOKEN_BANK as `0x${string}`) : undefined,
        abi: PermitTokenBankABI,
        functionName: 'balanceOf',
        args: [address],
    })


    const { data: tokenSymbol } = useReadContract({
        address: isValidAddresses ? (PERMIT_TOKEN as `0x${string}`) : undefined,
        abi: PermitTokenABI,
        functionName: 'symbol',
    })

    // Read token decimals
    const { data: decimals } = useReadContract({
        address: isValidAddresses ? (PERMIT_TOKEN as `0x${string}`) : undefined,
        abi: PermitTokenABI,
        functionName: 'decimals',
    })

    // Read token name
    const { data: tokenName } = useReadContract({
        address: isValidAddresses ? (PERMIT_TOKEN as `0x${string}`) : undefined,
        abi: PermitTokenABI,
        functionName: 'name',
    })

    // Read token version
    const { data: tokenVersion } = useReadContract({
        address: isValidAddresses ? (PERMIT_TOKEN as `0x${string}`) : undefined,
        abi: PermitTokenABI,
        functionName: 'eip712Domain',
    })

    // Sign typed data
    const { signTypedDataAsync } = useSignTypedData()

    // Write contract for permit deposit
    const { writeContractAsync } = useWriteContract()

    const handlePermitDeposit = async () => {
        try {
            if (!isValidAddresses) {
                message.error('Contract addresses are not valid')
                return
            }

            if (!address) {
                message.error('Please connect your wallet first')
                return
            }

            if (!amount || parseFloat(amount) <= 0) {
                message.error('Please enter a valid amount')
                return
            }

            if (!decimals) {
                message.error('Failed to get token decimals')
                return
            }

            if (!tokenName || !tokenVersion) {
                message.error('Failed to get token name or version')
                return
            }

            const depositAmount = parseEther(amount)
            if (tokenBalance && depositAmount > BigInt(tokenBalance.toString())) {
                message.error('Insufficient token balance')
                return
            }

            setLoading(true)
            const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600) // 1 hour from now

            message.loading('Signing permit...', 0)
            // Sign the permit data
            const sign_data:any = {
                domain: {
                    name: tokenName as string,
                    version: (tokenVersion as any)[2] as string, // version is the third element in the eip712Domain return value
                    chainId: BigInt(chainId),
                    verifyingContract: PERMIT_TOKEN as `0x${string}`,
                },
                types: {
                    EIP712Domain: [
                        { name: 'name', type: 'string' },
                        { name: 'version', type: 'string' },
                        { name: 'chainId', type: 'uint256' },
                        { name: 'verifyingContract', type: 'address' },
                    ],
                    Permit: [
                        { name: 'owner', type: 'address' },
                        { name: 'spender', type: 'address' },
                        { name: 'value', type: 'uint256' },
                        { name: 'nonce', type: 'uint256' },
                        { name: 'deadline', type: 'uint256' },
                    ],
                },
                primaryType: 'Permit',
                message: {
                    owner: address,
                    spender: PERMIT_TOKEN_BANK as `0x${string}`,
                    value: depositAmount,
                    nonce: BigInt(nonce?.toString() || '0'),
                    deadline: deadline,
                },
            }
            console.log('sign_data------>',sign_data);
            
            const signature = await signTypedDataAsync(sign_data)

            // Split signature into r, s, v
            const r = signature.slice(0, 66)
            const s = '0x' + signature.slice(66, 130)
            const v = parseInt(signature.slice(130, 132), 16)

            message.loading('Executing permit deposit...', 0)
            // Execute permit deposit
            const hash = await writeContractAsync({
                address: PERMIT_TOKEN_BANK as `0x${string}`,
                abi: PermitTokenBankABI,
                functionName: 'permitDeposit',
                args: [depositAmount, deadline, v, r, s],
            })

            message.destroy()
            message.success('Token deposit successful!')
            setAmount('')
            
            // Refetch balances after successful deposit
            await Promise.all([
                refetchNonce(),
                refetchTokenBalance(),
                refetchBankBalance()
            ])
        } catch (error) {
            message.destroy()
            console.error('Error during permit deposit:', error)
            if (error instanceof Error) {
                if (error.message.includes('User rejected')) {
                    message.error('Transaction rejected by user')
                } else if (error.message.includes('insufficient funds')) {
                    message.error('Insufficient token balance')
                } else if (error.message.includes('expired')) {
                    message.error('Permit expired. Please try again.')
                } else if (error.message.includes('invalid signature')) {
                    message.error('Invalid signature. Please try again.')
                } else {
                    message.error('Error during permit deposit: ' + error.message)
                }
            } else {
                message.error('Error during permit deposit')
            }
        } finally {
            setLoading(false)
        }
    }

    const handleDeposit = async () => {
        try {
            if (!isValidAddresses) {
                message.error('Contract addresses are not valid')
                return
            }

            if (!address) {
                message.error('Please connect your wallet first')
                return
            }

            if (!amount || parseFloat(amount) <= 0) {
                message.error('Please enter a valid amount')
                return
            }

            const depositAmount = parseEther(amount)
            if (tokenBalance && depositAmount > BigInt(tokenBalance.toString())) {
                message.error('Insufficient token balance')
                return
            }

            setLoading(true)
            message.loading('Depositing tokens...', 0)

            // First approve the bank contract to spend tokens
            await writeContractAsync({
                address: PERMIT_TOKEN as `0x${string}`,
                abi: PermitTokenABI,
                functionName: 'approve',
                args: [PERMIT_TOKEN_BANK, depositAmount],
            })

            // Then deposit the tokens
            const hash = await writeContractAsync({
                address: PERMIT_TOKEN_BANK as `0x${string}`,
                abi: PermitTokenBankABI,
                functionName: 'deposit',
                args: [depositAmount],
            })

            message.destroy()
            message.success('Token deposit successful!')
            setAmount('')
            
            // Refetch balances after successful deposit
            await Promise.all([
                refetchTokenBalance(),
                refetchBankBalance()
            ])
        } catch (error) {
            message.destroy()
            console.error('Error during deposit:', error)
            if (error instanceof Error) {
                if (error.message.includes('User rejected')) {
                    message.error('Transaction rejected by user')
                } else if (error.message.includes('insufficient funds')) {
                    message.error('Insufficient token balance')
                } else {
                    message.error('Error during deposit: ' + error.message)
                }
            } else {
                message.error('Error during deposit')
            }
        } finally {
            setLoading(false)
        }
    }

    const handleWithdraw = async () => {
        try {
            if (!isValidAddresses) {
                message.error('Contract addresses are not valid')
                return
            }

            if (!address) {
                message.error('Please connect your wallet first')
                return
            }

            if (!amount || parseFloat(amount) <= 0) {
                message.error('Please enter a valid amount')
                return
            }

            const withdrawAmount = parseEther(amount)
            if (bankBalance && withdrawAmount > BigInt(bankBalance.toString())) {
                message.error('Insufficient bank balance')
                return
            }

            setLoading(true)
            message.loading('Withdrawing tokens...', 0)

            const hash = await writeContractAsync({
                address: PERMIT_TOKEN_BANK as `0x${string}`,
                abi: PermitTokenBankABI,
                functionName: 'withdraw',
                args: [withdrawAmount],
            })

            message.destroy()
            message.success('Token withdrawal successful!')
            setAmount('')
            
            // Refetch balances after successful withdrawal
            await Promise.all([
                refetchTokenBalance(),
                refetchBankBalance()
            ])
        } catch (error) {
            message.destroy()
            console.error('Error during withdrawal:', error)
            if (error instanceof Error) {
                if (error.message.includes('User rejected')) {
                    message.error('Transaction rejected by user')
                } else if (error.message.includes('insufficient funds')) {
                    message.error('Insufficient bank balance')
                } else {
                    message.error('Error during withdrawal: ' + error.message)
                }
            } else {
                message.error('Error during withdrawal')
            }
        } finally {
            setLoading(false)
        }
    }

    if (!isValidAddresses) {
        return (
            <Card title="Permit TokenBank" className="max-w-md mx-auto mt-8">
                <Text type="danger">Contract addresses are not properly configured. Please check your configuration.</Text>
            </Card>
        )
    }

    return (
        <Card title="Permit TokenBank" className="max-w-md mx-auto mt-8">
            <Space direction="vertical" size="large" style={{ width: '100%' }}>
                <div>
                    <Text>Token Balance: {tokenBalance ? parseFloat(tokenBalance.toString()) / 1e18 : 0} {tokenSymbol as string}</Text>
                    <br />
                    <Text>Bank Balance: {bankBalance ? parseFloat(bankBalance.toString()) / 1e18 : 0} {tokenSymbol as string}</Text>
                </div>
                <div>
                    <label className="block mb-2">Amount ({tokenSymbol as string})</label>
                    <Input
                        type="number"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        placeholder={`Enter amount in ${tokenSymbol as string}`}
                        min="0"
                        step="0.1"
                    />
                </div>
                <Space>
                    {/* 常规approve+deposit转账 */}
                    <Button
                        type="primary"
                        onClick={handleDeposit}
                        disabled={loading}
                    >
                        Deposit with approve
                    </Button>
                    {/* 通过签名替代approve，实现deposit（节省gas费用） */}
                    <Button
                        type="primary"
                        onClick={handlePermitDeposit}
                        disabled={loading}
                    >
                        Deposit with Signture
                    </Button>
                    <Button
                        type="primary"
                        onClick={handleWithdraw}
                        disabled={loading}
                    >
                        Withdraw
                    </Button>
                </Space>
            </Space>
        </Card>
    )
}

export default PermitTokenBank