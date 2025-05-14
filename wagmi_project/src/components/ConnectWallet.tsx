import { useAccount, useConnect, useDisconnect, Connector,useChainId, useSwitchChain } from 'wagmi'
import { Button, Dropdown, Space, Typography, message } from 'antd'
import { WalletFilled, LogoutOutlined, SwapOutlined } from '@ant-design/icons'
// import { useWeb3Modal } from '@web3modal/wagmi/react'
import { anvil, sepolia } from '@/config'

const { Text } = Typography

const ConnectWallet = () => {
    const { address, isConnected } = useAccount()
    const { connectors, connect } = useConnect()
    const { disconnect } = useDisconnect()
    // const modal = useWeb3Modal()
    const chainId = useChainId()
    const { switchChain } = useSwitchChain()

    const handleConnect = async (connector: Connector) => {
        try {
            await connect({ connector })
        } catch (error) {
            console.error('Connection error:', error)
            if (error instanceof Error) {
                if (error.message.includes('User rejected')) {
                    message.error('Connection rejected by user')
                } else if (error.message.includes('WalletConnect')) {
                    message.error('WalletConnect connection failed. Please try MetaMask or other injected wallets.')
                } else {
                    message.error('Failed to connect wallet: ' + error.message)
                }
            } else {
                message.error('Failed to connect wallet')
            }
        }
    }

    const handleDisconnect = () => {
        try {
            disconnect()
            message.success('Wallet disconnected')
        } catch (error) {
            console.error('Disconnect error:', error)
            message.error('Failed to disconnect wallet')
        }
    }

    const handleSwitchNetwork = async (targetChainId: number) => {
        try {
            if (!switchChain) {
                message.error('Network switching is not supported')
                return
            }

            // 显示切换网络的消息
            message.loading('Switching network...', 0)

            // 执行网络切换
            await switchChain({ chainId: targetChainId })

            // 等待网络切换完成
            await new Promise(resolve => setTimeout(resolve, 2000))
            message.destroy() // 清除加载消息
            message.success('Network switched successfully')
        
        } catch (error) {
            message.destroy() // 清除加载消息
            console.error('Network switch error:', error)
            if (error instanceof Error) {
                if (error.message.includes('User rejected')) {
                    message.error('Network switch rejected by user')
                } else if (error.message.includes('not configured')) {
                    message.error('Network not configured in your wallet. Please add it manually.')
                } else if (error.message.includes('timeout') || error.message.includes('network')) {
                    message.error('Network connection timeout. Please check your internet connection.')
                } else {
                    message.error('Failed to switch network: ' + error.message)
                }
            } else {
                message.error('Failed to switch network')
            }
        }
    }

    const networkItems = [
        {
            key: 'anvil',
            label: 'Anvil',
            onClick: () => handleSwitchNetwork(anvil.id)
        },
        {
            key: 'sepolia',
            label: 'Sepolia',
            onClick: () => handleSwitchNetwork(sepolia.id)
        }
    ]

    const walletItems = connectors.map((connector) => ({
        key: connector.id,
        label: connector.name,
        onClick: async () => {
            try {
                if (connector.name.toLowerCase().includes('walletconnect')) {
                    // await modal.open()
                } else {
                    handleConnect(connector)
                }
            } catch (error) {
                console.error('Wallet selection error:', error)
                message.error('Failed to open wallet selection')
            }
        },
    }))

    const items = [
        {
            key: 'disconnect',
            label: (
                <Space direction="vertical" style={{ width: '100%' }}>
                    <Button
                        danger
                        icon={<LogoutOutlined />}
                        block
                        type="link"
                        onClick={handleDisconnect}
                    >
                        Disconnect
                    </Button>
                </Space>
            ),
        }
    ]

    const getNetworkName = (id: number) => {
        switch (id) {
            case anvil.id:
                return 'Anvil'
            case sepolia.id:
                return 'Sepolia'
            default:
                return `Chain ${id}`
        }
    }

    return isConnected ? (
        <Space>
            <Dropdown menu={{ items: networkItems }} placement="bottomLeft">
                <Button icon={<SwapOutlined />}>
                    {getNetworkName(chainId)}
                </Button>
            </Dropdown>
            <Dropdown menu={{ items }} placement="bottom">
                <Button>
                    <WalletFilled />
                    <Text>{address?.slice(0, 6)}...{address?.slice(-4)}</Text>
                   
                </Button>
            </Dropdown>
        </Space>
    ) : (
        <Space>
            <Dropdown menu={{ items: networkItems }} placement="bottomLeft">
                <Button icon={<SwapOutlined />}>
                    {getNetworkName(chainId)}
                </Button>
            </Dropdown>
            <Dropdown menu={{ items: walletItems }} placement="bottomRight">
                <Button type="primary">
                    Connect Wallet
                </Button>
            </Dropdown>
        </Space>
    )
}

export default ConnectWallet