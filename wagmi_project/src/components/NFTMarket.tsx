import { useState, useEffect } from 'react';
import { Card, Button, Form, Input, message, Space, Typography, Select, Table, Tag, Modal, Row, Col, Image, Divider } from 'antd';
import { useAccount, useWriteContract, useReadContract, useConfig, useChainId, useBalance, usePublicClient } from 'wagmi';
import { waitForTransactionReceipt } from 'wagmi/actions';
import { NFT_MARKET_ABI, ERC721_NFT_ABI } from '@/config';
import { parseEther, formatEther } from 'viem';

const { Title, Text } = Typography;
const { Option } = Select;

interface NFTMarketProps {
  marketAddress: `0x${string}`;
  nftAddress: `0x${string}`;
}

interface NFTListing {
  tokenId: bigint;
  seller: `0x${string}`;
  price: bigint;
  isActive: boolean;
}

interface NFTInfo {
  tokenId: bigint;
  owner: `0x${string}`;
  listing?: NFTListing;
}

const NFTMarket = ({ marketAddress, nftAddress }: NFTMarketProps) => {
  const [form] = Form.useForm();
  const { address } = useAccount();
  const [listLoading, setListLoading] = useState(false);
  const [buyLoading, setBuyLoading] = useState(false);
  const [unlistLoading, setUnlistLoading] = useState(false);
  const [selectedNFT, setSelectedNFT] = useState<NFTListing | null>(null);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const config = useConfig();
  const publicClient = usePublicClient();
  const [nftInfo, setNftInfo] = useState<NFTInfo | null>(null);

  // 获取用户 ETH 余额
  const { data: ethBalance } = useBalance({
    address,
  });

  // 获取市场合约信息
  const { data: feePercentage } = useReadContract({
    address: marketAddress,
    abi: NFT_MARKET_ABI,
    functionName: 'feePercentage',
  }) as { data: bigint | undefined };

  // 获取 NFT 合约信息
  const { data: nftName } = useReadContract({
    address: nftAddress,
    abi: ERC721_NFT_ABI,
    functionName: 'name',
  });

  const { data: nftSymbol } = useReadContract({
    address: nftAddress,
    abi: ERC721_NFT_ABI,
    functionName: 'symbol',
  });

  // 获取用户拥有的 NFT 列表
  const { data: balanceOf, refetch: balanceOfRefetch } = useReadContract({
    address: nftAddress,
    abi: ERC721_NFT_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) as any;

  // 获取所有上架的 NFT
  const [listings, setListings] = useState<NFTListing[]>([]);

  // 获取当前已铸造的 NFT 数量
  const { data: nextTokenId } = useReadContract({
    address: nftAddress,
    abi: ERC721_NFT_ABI,
    functionName: 'nextTokenId',
  });

  // 获取用户拥有的所有 NFT
  const [ownedNFTs, setOwnedNFTs] = useState<bigint[]>([]);
  const [loadingOwnedNFTs, setLoadingOwnedNFTs] = useState(false);

  // 获取所有上架的 NFT 信息
  useEffect(() => {
    const fetchListings = async () => {
      if (!nextTokenId) {
        console.log('nextTokenId is not available yet');
        return;
      }

      console.log('Fetching listings, nextTokenId:', nextTokenId.toString());
      const activeListings: NFTListing[] = [];

      // 从 1 开始遍历到 nextTokenId-1，因为 nextTokenId 是下一个要铸造的 ID
      for (let i = 0; i < Number(nextTokenId); i++) {
        try {
          console.log('Checking tokenId:', i);
          const listing = await publicClient?.readContract({
            address: marketAddress,
            abi: NFT_MARKET_ABI,
            functionName: 'getListing',
            args: [nftAddress, BigInt(i)],
          }) as [string, bigint, boolean];

          console.log('Listing for tokenId', i, ':', listing);

          if (listing && listing[2]) { // isActive
            console.log('Found active listing for tokenId:', i);
            activeListings.push({
              tokenId: BigInt(i),
              seller: listing[0] as `0x${string}`,
              price: listing[1],
              isActive: listing[2],
            });
          }
        } catch (error) {
          console.log('Error or no listing for tokenId:', i, error);
          // 如果 tokenId 未上架，忽略错误
          continue;
        }
      }
      console.log('Final active listings:', activeListings);
      setListings(activeListings);
    };

    if (marketAddress && nftAddress && publicClient) {
      console.log('Starting to fetch listings with:', {
        marketAddress,
        nftAddress,
        nextTokenId: nextTokenId?.toString()
      });
      fetchListings();
    } else {
      console.log('Missing required data:', {
        hasMarketAddress: !!marketAddress,
        hasNftAddress: !!nftAddress,
        hasPublicClient: !!publicClient
      });
    }
  }, [nextTokenId, marketAddress, nftAddress, publicClient]);

  // 获取用户拥有的所有 NFT
  useEffect(() => {
    const fetchOwnedNFTs = async () => {
      if (!address || !publicClient || !balanceOf || balanceOf === 0n) {
        setOwnedNFTs([]);
        return;
      }

      setLoadingOwnedNFTs(true);
      try {
        const tokenIds: bigint[] = [];
        const token_imgs: string[] = [];
        const balance = Number(balanceOf);

        for (let i = 0; i < balance; i++) {
          try {
            // 获取用户在索引 i 处拥有的 token ID
            const tokenId = await publicClient.readContract({
              address: nftAddress,
              abi: ERC721_NFT_ABI,
              functionName: 'tokenOfOwnerByIndex',
              args: [address, BigInt(i)],
            }) as bigint;
            tokenIds.push(tokenId);
          } catch (error) {
            console.error(`Error fetching token at index ${i}:`, error);
          }
        }

        setOwnedNFTs(tokenIds);
      } catch (error) {
        console.error('Error fetching owned NFTs:', error);
        message.error('Failed to load your NFTs');
      } finally {
        setLoadingOwnedNFTs(false);
      }
    };

    fetchOwnedNFTs();
  }, [address, publicClient, balanceOf, nftAddress]);

  const { writeContractAsync: listAsync } = useWriteContract();
  const { writeContractAsync: buyAsync } = useWriteContract();
  const { writeContractAsync: unlistAsync } = useWriteContract();
  const { writeContractAsync: approveAsync } = useWriteContract();

  // 处理上架 NFT
  const handleList = async (values: { tokenId: string; price: string }) => {
    try {
      setListLoading(true);

      if (!address) {
        throw new Error('Please connect your wallet first');
      }

      const tokenId = BigInt(values.tokenId);
      const price = parseEther(values.price);

      // 检查 NFT 是否已授权给市场合约
      const isApproved = await publicClient?.readContract({
        address: nftAddress,
        abi: ERC721_NFT_ABI,
        functionName: 'isApprovedForAll',
        args: [address, marketAddress],
      });

      if (!isApproved) {
        message.info('Approving NFT transfer...');
        const approveHash = await approveAsync({
          address: nftAddress,
          abi: ERC721_NFT_ABI,
          functionName: 'setApprovalForAll',
          args: [marketAddress, true],
        });

        await waitForTransactionReceipt(config, {
          hash: approveHash,
          timeout: 60000,
        });
      }

      const hash = await listAsync({
        address: marketAddress,
        abi: NFT_MARKET_ABI,
        functionName: 'list',
        args: [nftAddress, tokenId, price],
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash,
        timeout: 60000,
      });

      if (receipt.status === 'reverted') {
        throw new Error('List transaction reverted');
      }

      message.success('NFT listed successfully!');
      form.resetFields();
      balanceOfRefetch();
    } catch (error) {
      console.error('List failed:', error);
      message.error('List failed: ' + (error as Error).message);
    } finally {
      setListLoading(false);
    }
  };

  // 处理购买 NFT
  const handleBuy = async (listing: NFTListing) => {
    try {
      setBuyLoading(true);

      if (!address) {
        throw new Error('Please connect your wallet first');
      }

      if (address === listing.seller) {
        throw new Error('Cannot buy your own NFT');
      }

      const hash = await buyAsync({
        address: marketAddress,
        abi: NFT_MARKET_ABI,
        functionName: 'buyNFT',
        args: [nftAddress, listing.tokenId],
        value: listing.price,
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash,
        timeout: 60000,
      });

      if (receipt.status === 'reverted') {
        throw new Error('Buy transaction reverted');
      }

      message.success('NFT purchased successfully!');
      balanceOfRefetch();
    } catch (error) {
      console.error('Buy failed:', error);
      message.error('Buy failed: ' + (error as Error).message);
    } finally {
      setBuyLoading(false);
      setIsModalVisible(false);
    }
  };

  // 处理取消上架
  const handleUnlist = async (tokenId: bigint) => {
    try {
      setUnlistLoading(true);

      if (!address) {
        throw new Error('Please connect your wallet first');
      }

      const hash = await unlistAsync({
        address: marketAddress,
        abi: NFT_MARKET_ABI,
        functionName: 'unlist',
        args: [nftAddress, tokenId],
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash,
        timeout: 60000,
      });

      if (receipt.status === 'reverted') {
        throw new Error('Unlist transaction reverted');
      }

      message.success('NFT unlisted successfully!');
      balanceOfRefetch();
    } catch (error) {
      console.error('Unlist failed:', error);
      message.error('Unlist failed: ' + (error as Error).message);
    } finally {
      setUnlistLoading(false);
    }
  };

  // 处理查询 NFT 信息
  const handleQueryNFT = async (values: { tokenId: string }) => {
    try {
      const tokenId = BigInt(values.tokenId);

      // 获取 NFT 所有者
      const owner = await publicClient?.readContract({
        address: nftAddress,
        abi: ERC721_NFT_ABI,
        functionName: 'ownerOf',
        args: [tokenId],
      }) as `0x${string}`;

      // 获取上架信息
      let listing: NFTListing | undefined;
      try {
        const listingData = await publicClient?.readContract({
          address: marketAddress,
          abi: NFT_MARKET_ABI,
          functionName: 'getListing',
          args: [nftAddress, tokenId],
        }) as [string, bigint, boolean];

        if (listingData[2]) { // isActive
          listing = {
            tokenId,
            seller: listingData[0] as `0x${string}`,
            price: listingData[1],
            isActive: listingData[2],
          };
        }
      } catch (error) {
        console.log('NFT is not listed');
      }

      setNftInfo({
        tokenId,
        owner,
        listing,
      });

      message.success('NFT info retrieved successfully!');
    } catch (error) {
      console.error('Query failed:', error);
      message.error('Query failed: ' + (error as Error).message);
    } finally {
    }
  };

  const columns = [
    {
      title: 'Token ID',
      dataIndex: 'tokenId',
      key: 'tokenId',
      render: (tokenId: bigint) => tokenId.toString(),
    },
    {
      title: 'Seller',
      dataIndex: 'seller',
      key: 'seller',
      render: (seller: string) => (
        <Tag color={seller === address ? 'green' : 'blue'}>
          {seller === address ? 'You' : seller}
        </Tag>
      ),
    },
    {
      title: 'Price',
      dataIndex: 'price',
      key: 'price',
      render: (price: bigint) => `${formatEther(price)} ETH`,
    },
    {
      title: 'Action',
      key: 'action',
      render: (_: any, record: NFTListing) => (
        <Space>
          {record.seller === address ? (
            <Button
              danger
              disabled={unlistLoading}
              onClick={() => handleUnlist(record.tokenId)}
            >
              Unlist
            </Button>
          ) : (
            <Button
              type="primary"
              disabled={!address || buyLoading}
              onClick={() => {
                setSelectedNFT(record);
                setIsModalVisible(true);
              }}
            >
              Buy
            </Button>
          )}
        </Space>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <Title level={3} style={{ margin: 0, textAlign: "center" }}>NFT Market</Title>
      <Card style={{ maxWidth: 1200, margin: '0 auto', marginTop: 24 }}>
        <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }}>
          <Text>Market Contract: {nftName as string} ({nftSymbol as string})</Text>
          <Text>Fee Percentage: {feePercentage ? Number(feePercentage) / 100 : 0}%</Text>
          {address && (
            <Text>Your ETH Balance: {formatEther(ethBalance?.value || 0n)} ETH</Text>
          )}
          {address && (
            <Text>Your NFTs: {balanceOf?.toString()}</Text>
          )}
        </Space>

        {address && balanceOf && (
          <>
            <Divider>Your NFTs</Divider>
            <Row gutter={[16, 16]}>
              {loadingOwnedNFTs ? (
                <Col span={24} style={{ textAlign: 'center' }}>
                  <Text>Loading your NFTs...</Text>
                </Col>
              ) : ownedNFTs.length > 0 ? (
                ownedNFTs.map(tokenId => (
                  <Col key={tokenId.toString()} xs={24} sm={12} md={8} lg={6}>
                    <Card
                      hoverable
                    >
                      <Card.Meta
                        title={`NFT #${tokenId.toString()}`}
                        description={
                          <Space direction="vertical" style={{ width: '100%' }}>
                            <Input
                              addonAfter={`$ETH`}
                              style={{ width: '100%' }}
                              onChange={(e) => {
                                form.setFieldsValue({
                                  tokenId: tokenId.toString(),
                                  price: e.target.value
                                });
                              }}
                            />
                            <Space>
                              <Button
                                type="primary"
                                size="small"
                                disabled={listLoading}
                                onClick={() => {
                                  const price = form.getFieldValue('price');
                                  if (price) {
                                    handleList({
                                      tokenId: tokenId.toString(),
                                      price: price
                                    });
                                  } else {
                                    message.error('Please enter a price');
                                  }
                                }}
                              >
                                List
                              </Button>
                              <Button
                                size="small"
                                onClick={() => handleQueryNFT({ tokenId: tokenId.toString() })}
                              >
                                View Details
                              </Button>
                            </Space>
                          </Space>
                        }
                      />
                    </Card>
                  </Col>
                ))
              ) : (
                <Col span={24} style={{ textAlign: 'center' }}>
                  <Text>You don't own any NFTs yet.</Text>
                </Col>
              )}
            </Row>
          </>
        )}

        {nftInfo && (
          <Card title={`NFT #${nftInfo.tokenId.toString()} Info`} style={{ marginTop: 24 }}>
            <p><strong>Owner:</strong> {nftInfo.owner === address ? 'You' : nftInfo.owner}</p>
            {nftInfo.listing && (
              <>
                <p><strong>Listed:</strong> Yes</p>
                <p><strong>Price:</strong> {formatEther(nftInfo.listing.price)} ETH</p>
                <p><strong>Seller:</strong> {nftInfo.listing.seller === address ? 'You' : nftInfo.listing.seller}</p>
              </>
            )}
          </Card>
        )}

        <Divider>Market Listings</Divider>
        <Table
          dataSource={listings}
          columns={columns}
          rowKey={(record) => record.tokenId.toString()}
          pagination={{ pageSize: 5 }}
        />

        <Modal
          title="Confirm Purchase"
          open={isModalVisible}
          onCancel={() => setIsModalVisible(false)}
          footer={[
            <Button key="back" onClick={() => setIsModalVisible(false)}>
              Cancel
            </Button>,
            <Button
              key="submit"
              type="primary"
              loading={buyLoading}
              onClick={() => selectedNFT && handleBuy(selectedNFT)}
            >
              Confirm Purchase
            </Button>,
          ]}
        >
          {selectedNFT && (
            <>
              <p>You are about to purchase NFT #{selectedNFT.tokenId.toString()}</p>
              <p>Price: {formatEther(selectedNFT.price)} ETH</p>
              <p>Seller: {selectedNFT.seller}</p>
            </>
          )}
        </Modal>
      </Card>
    </div>
  );
};

export default NFTMarket;