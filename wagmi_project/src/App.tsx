import { BrowserRouter, Routes, Route, Link, useLocation } from 'react-router-dom';
import { Layout, Menu, Typography } from 'antd';
import { HomeOutlined, RocketOutlined, ShopOutlined, FileTextOutlined } from '@ant-design/icons';
import Home from './pages/Home';
import MintNFT from './pages/MintNFT';
import NFTMarket from './pages/NFTMarket';
import PermitTokenBank from './pages/PermitTokenBank';
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config, projectId } from '@/config'
// import { createWeb3Modal } from '@web3modal/wagmi/react'
import ConnectWallet from './components/ConnectWallet'

const { Header, Sider, Content } = Layout;
const { Title } = Typography;

// 创建 QueryClient 实例
const queryClient = new QueryClient()

// 创建 Web3Modal
// createWeb3Modal({
//   wagmiConfig: config,
//   projectId,
//   themeMode: 'light',
// })

// Navigation component with active state
const Navigation = () => {
  const location = useLocation();

  const navItems = [
    {
      key: '/',
      icon: <HomeOutlined />,
      label: 'TokenBank',
      path: '/'
    },
    {
      key: '/mint-nft',
      icon: <RocketOutlined />,
      label: 'Mint NFT',
      path: '/mint-nft'
    },
    {
      key: '/nft-market',
      icon: <ShopOutlined />,
      label: 'NFT Market',
      path: '/nft-market'
    },
    {
      key: '/permit-token-bank',
      icon: <FileTextOutlined />,
      label: 'Permit TokenBank',
      path: '/permit-token-bank'
    },
  ];

  return (
    <Menu
    theme="light"
    mode="horizontal"
    defaultSelectedKeys={['2']}
    style={{ flex: 1, minWidth: 0 }}
      items={navItems.map(item => ({
        key: item.key,
        icon: item.icon,
        label: <Link to={item.path}>{item.label}</Link>
      }))}
    />
  );
};

function App() {
  return (
    <WagmiProvider config={config as any}>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <Layout>
            <Header
              style={{
                position: 'sticky',
                top: 0,
                zIndex: 1,
                width: '100%',
                display: 'flex',
                alignItems: 'center',
                background: '#fff',
                padding: '0 10px'
              }}
            >
              <Navigation />
              <ConnectWallet />
            </Header>
            <Content style={{
              margin: '88px 24px 24px',
              overflow: 'initial',
              background: '#fff',
              padding: 24,
              borderRadius: 4,
              minHeight: 280
            }}>
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/mint-nft" element={<MintNFT />} />
                <Route path="/nft-market" element={<NFTMarket />} />
                <Route path="/permit-token-bank" element={<PermitTokenBank />} />
              </Routes>
            </Content>
            {/* <Footer style={{ textAlign: 'center' }}>
              Ant Design ©{new Date().getFullYear()} Created by Ant UED
            </Footer> */}
          </Layout>
        </BrowserRouter>
      </QueryClientProvider>
    </WagmiProvider>
  )
}

export default App
