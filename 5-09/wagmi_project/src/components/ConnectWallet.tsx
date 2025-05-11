import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { Space, Button, Typography, message, Dropdown } from 'antd'
import type { MenuProps } from 'antd'
import { LogoutOutlined, WalletFilled } from '@ant-design/icons';
const { Text } = Typography;

const ConnectWallet = () => {
    const { address, status } = useAccount()
    const { connectors, connect } = useConnect()
    const { disconnect } = useDisconnect()


    const handleConnect = async (connector: any) => {
        try {
            await connect({ connector })
            message.success('Wallet connected successfully!')
        } catch (error) {
            message.error('Failed to connect wallet')
        }
    }

    const handleDisconnect = () => {
        disconnect()
        message.success('Wallet disconnected')
    }

    const walletItems: MenuProps['items'] = connectors.map((connector) => ({
        key: connector.uid,
        label: connector.name,
        onClick: () => handleConnect(connector),
    }))
    const items: MenuProps['items'] = [
        {
            key: '1',
            label: (
                <Space direction="vertical" style={{ width: '100%', }}>
                    <Button danger icon={<LogoutOutlined />} iconPosition="end" block type="link" onClick={handleDisconnect}>
                        Disconnect
                    </Button>
                </Space>
            ),
        }]
    return status === 'connected' ? (

        <Dropdown menu={{ items }} placement="bottom">
            <Button  >
                <WalletFilled />
                <Text >{address?.slice(0, 6)}...{address?.slice(-4)}</Text>
            </Button>
        </Dropdown>
    ) : (
        <Dropdown menu={{ items: walletItems }} placement="bottomRight">
            <Button type="primary" size="small">
                Connect Wallet
            </Button>
        </Dropdown>
    )
}

export default ConnectWallet