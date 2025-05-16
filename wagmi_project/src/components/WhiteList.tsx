import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useChainId, useSignTypedData, usePublicClient } from 'wagmi'
import { Input, Button, Table, Typography, Card, Space, message, Tag, Tooltip, Modal, DatePicker } from 'antd'
import dayjs from 'dayjs'
import { CopyOutlined, DownloadOutlined } from '@ant-design/icons'
import { parseEther } from 'viem'
import { whitelistApi } from '../utils/request'


const { Text, Title } = Typography
const { TextArea } = Input


interface WhitelistEntry {
  address: string;
  tokenId: number;
  deadline: bigint;
  signature?: string;
  key: string;
  nonce?: bigint;
}
interface WhiteListProps {
    nftAddress: `0x${string}`;
    nftABI: any
}
function WhiteList({ nftAddress, nftABI }: WhiteListProps) {
  const NFT_CONTRACT = nftAddress;
  const ERC721WithSignatureABI = nftABI;

  const { address, isConnected } = useAccount()
  const chainId = useChainId()
  const publicClient = usePublicClient()
  const [loading, setLoading] = useState(false)
  const [isOwner, setIsOwner] = useState(false)
  const [addresses, setAddresses] = useState('')
  const [startTokenId, setStartTokenId] = useState(0)
  const [deadline, setDeadline] = useState<dayjs.Dayjs | null>(dayjs().add(7, 'day'))
  const [whitelist, setWhitelist] = useState<WhitelistEntry[]>([])
  const [showExport, setShowExport] = useState(false)
  const [exportData, setExportData] = useState('')

  // 读取合约所有者
  const { data: contractOwner } = useReadContract({
    address: NFT_CONTRACT as `0x${string}`,
    abi: ERC721WithSignatureABI,
    functionName: 'owner',
  })

  // 读取当前 tokenId
  const { data: nextTokenId } = useReadContract({
    address: NFT_CONTRACT as `0x${string}`,
    abi: ERC721WithSignatureABI,
    functionName: 'nextTokenId',
  })

  // 读取合约名称
  const { data: contractName } = useReadContract({
    address: NFT_CONTRACT as `0x${string}`,
    abi: ERC721WithSignatureABI,
    functionName: 'name',
  })

  // 签名函数
  const { signTypedDataAsync } = useSignTypedData()
  
  // 通过公共客户端获取 nonce
  const fetchNonce = async (userAddress: string): Promise<bigint> => {
    try {
      if (!publicClient) return BigInt(0)
      
      const data = await publicClient.readContract({
        address: NFT_CONTRACT as `0x${string}`,
        abi: ERC721WithSignatureABI,
        functionName: 'nonces',
        args: [userAddress as `0x${string}`],
      })
      
      return data as bigint
    } catch (error) {
      console.error('Error fetching nonce:', error)
      return BigInt(0)
    }
  }

  // 检查是否是合约所有者
  useEffect(() => {
    if (address && contractOwner) {
      // 确保 contractOwner 是字符串类型
      const ownerStr = typeof contractOwner === 'string' 
        ? contractOwner 
        : contractOwner?.toString() || ''
      
      setIsOwner(address.toLowerCase() === ownerStr.toLowerCase())
    } else {
      setIsOwner(false)
    }
  }, [address, contractOwner])

  // 当获取到 nextTokenId 时，更新 startTokenId
  useEffect(() => {
    if (nextTokenId !== undefined) {
      setStartTokenId(Number(nextTokenId))
    }
  }, [nextTokenId])

  // 准备白名单数据
  const prepareWhitelist = () => {
    if (!addresses.trim()) {
      message.error('Please enter at least one address')
      return
    }

    if (!deadline) {
      message.error('Please select a deadline')
      return
    }

    const addressList = addresses
      .split('\n')
      .map(addr => addr.trim())
      .filter(addr => addr && addr.startsWith('0x'))

    if (addressList.length === 0) {
      message.error('No valid addresses found')
      return
    }

    const deadlineTimestamp = BigInt(Math.floor(deadline.unix()))

    const newWhitelist: WhitelistEntry[] = addressList.map((addr, index) => ({
      address: addr,
      tokenId: startTokenId + index,
      deadline: deadlineTimestamp,
      key: `${addr}-${startTokenId + index}`,
    }))

    setWhitelist(newWhitelist)
    message.success(`Prepared ${newWhitelist.length} addresses for signing`)
    
    // 获取所有地址的 nonce
    fetchNonces(newWhitelist)
  }
  
  // 获取多个地址的 nonce
  const fetchNonces = async (entries: WhitelistEntry[]) => {
    setLoading(true)
    try {
      const updatedEntries = [...entries]
      for (let i = 0; i < updatedEntries.length; i++) {
        // 获取当前用户地址的nonce(防止重放攻击)
        const nonce = await fetchNonce(updatedEntries[i].address)
        updatedEntries[i] = { ...updatedEntries[i], nonce }
      }
      
      setWhitelist(updatedEntries)
    } catch (error) {
      console.error('Error fetching nonces:', error)
      message.error('Failed to fetch some nonces')
    } finally {
      setLoading(false)
    }
  }

  // 为单个地址生成签名
  const generateSignature = async (entry: WhitelistEntry) => {
    try {
      if (!entry.nonce) {
        entry.nonce = await fetchNonce(entry.address)
      }
      console.log('Generating signature with params:', {
        address: entry.address,
        tokenId: entry.tokenId,
        nonce: entry.nonce?.toString(),
        deadline: entry.deadline.toString(),
        contractName
      });
      
      const sign_data:any = {
        domain: {
          name: contractName as string, // 使用合约实际名称
          version: '1',
          chainId: BigInt(chainId),
          verifyingContract: NFT_CONTRACT as `0x${string}`,
        },
        types: {
          EIP712Domain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
            { name: 'chainId', type: 'uint256' },
            { name: 'verifyingContract', type: 'address' },
          ],
          Mint: [
            { name: 'to', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        },
        primaryType: 'Mint',
        message: {
          to: entry.address as `0x${string}`,
          tokenId: BigInt(entry.tokenId),
          nonce: entry.nonce,
          deadline: entry.deadline,
        },
      }
      console.log('sign_data->',sign_data);
      
      const signature = await signTypedDataAsync(sign_data)

      // Save signature to server
      try {
        await whitelistApi.saveSignature(
          entry.address, 
          signature, 
          entry.tokenId, 
          Number(entry.deadline),
          // entry.nonce ? Number(entry.nonce) : 0 // 保存nonce到服务器
        )
        message.success(`Signature saved for ${entry.address}`)
      } catch (error) {
        console.error('Error saving signature to server:', error)
        message.error(`Failed to save signature for ${entry.address}`)
      }

      return signature
    } catch (error) {
      console.error('Error generating signature:', error)
      message.error(`Error generating signature for ${entry.address}`)
      return undefined
    }
  }

  // 批量生成签名
  const generateBatchSignatures = async () => {
    if (!isOwner) {
      message.error('Only the contract owner can generate signatures')
      return
    }

    if (whitelist.length === 0) {
      message.error('No whitelist prepared')
      return
    }

    setLoading(true)
    const updatedWhitelist = [...whitelist]

    try {
      for (let i = 0; i < updatedWhitelist.length; i++) {
        const signature = await generateSignature(updatedWhitelist[i])
        updatedWhitelist[i] = { ...updatedWhitelist[i], signature }
        
        // 更新状态以显示进度
        setWhitelist([...updatedWhitelist])
        
        // 添加一点延迟，避免钱包签名请求过快
        await new Promise(resolve => setTimeout(resolve, 500))
      }
      message.success('All signatures generated successfully')
    } catch (error) {
      console.error('Error during batch signature generation:', error)
      message.error('Failed to generate all signatures')
    } finally {
      setLoading(false)
    }
  }


  // 复制签名数据
  const copySignatures = () => {
    if (!exportData) return
    
    navigator.clipboard.writeText(exportData)
      .then(() => message.success('Signatures copied to clipboard'))
      .catch(() => message.error('Failed to copy signatures'))
  }

  // 下载签名数据
  const downloadSignatures = () => {
    if (!exportData) return
    
    const blob = new Blob([exportData], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `whitelist-signatures-${Date.now()}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  // 表格列定义
  const columns = [
    {
      title: 'Address',
      dataIndex: 'address',
      key: 'address',
      ellipsis: true,
    },
    {
      title: 'Token ID',
      dataIndex: 'tokenId',
      key: 'tokenId',
    },
    {
      title: 'Deadline',
      dataIndex: 'deadline',
      key: 'deadline',
      render: (deadline: bigint) => new Date(Number(deadline) * 1000).toLocaleString(),
    },
    {
      title: 'Nonce',
      dataIndex: 'nonce',
      key: 'nonce',
      render: (nonce?: bigint) => nonce?.toString() || 'Loading...',
    },
    {
      title: 'Status',
      key: 'status',
      render: (_: unknown, record: WhitelistEntry) => (
        record.signature 
          ? <Tag color="green">Signed</Tag>
          : <Tag color="orange">Pending</Tag>
      ),
    },
  ]

  return (
    <Card title="Whitelist Signature Generator" className="max-w-4xl mx-auto mt-8">
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        {!isConnected ? (
          <Text type="warning">Please connect your wallet</Text>
        ) : !isOwner ? (
          <Text type="danger">Only the contract owner can generate whitelist signatures</Text>
        ) : (
          <>
            <div>
              <Title level={5}>Current Contract: {NFT_CONTRACT}</Title>
              <Text type="success">You are the contract owner</Text>
            </div>

            <div>
              <Text>Enter addresses (one per line):</Text>
              <TextArea
                rows={6}
                value={addresses}
                onChange={e => setAddresses(e.target.value)}
                placeholder="0x123...\n0x456...\n0x789..."
                disabled={loading}
              />
            </div>

            <Space>
              <div>
                <Text>Starting Token ID:</Text>
                <Input
                  type="number"
                  value={startTokenId}
                  onChange={e => setStartTokenId(parseInt(e.target.value) || 0)}
                  disabled={loading}
                  style={{ width: 120 }}
                />
              </div>

              <div>
                <Text>Signature Deadline:</Text>
                <DatePicker
                  value={deadline}
                  onChange={setDeadline}
                  disabled={loading}
                  showTime
                />
              </div>
            </Space>

            <div>
              <Button
                type="primary"
                onClick={prepareWhitelist}
                disabled={loading || !addresses.trim()}
              >
                Prepare Whitelist
              </Button>
            </div>

            {whitelist.length > 0 && (
              <>
                <Table 
                  dataSource={whitelist} 
                  columns={columns} 
                  pagination={false}
                  size="small"
                  scroll={{ y: 300 }}
                />

                <Space>
                  <Button
                    type="primary"
                    onClick={generateBatchSignatures}
                    loading={loading}
                    disabled={whitelist.length === 0}
                  >
                    Generate Signatures
                  </Button>

             
                </Space>
              </>
            )}
          </>
        )}
      </Space>

      <Modal
        title="Export Signatures"
        open={showExport}
        onCancel={() => setShowExport(false)}
        footer={[
          <Button key="close" onClick={() => setShowExport(false)}>
            Close
          </Button>,
          <Button
            key="copy"
            icon={<CopyOutlined />}
            onClick={copySignatures}
          >
            Copy
          </Button>,
          <Button
            key="download"
            type="primary"
            icon={<DownloadOutlined />}
            onClick={downloadSignatures}
          >
            Download
          </Button>,
        ]}
        width={800}
      >
        <TextArea
          value={exportData}
          rows={20}
          readOnly
        />
      </Modal>
    </Card>
  )
}

export default WhiteList
