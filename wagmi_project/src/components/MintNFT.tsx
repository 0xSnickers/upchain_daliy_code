import { useState, useEffect } from 'react';
import { Card, Button, Form, message, Space, Typography, Tabs, Spin, Result } from 'antd';
import { useAccount, useWriteContract, useReadContract, useConfig, useWaitForTransactionReceipt } from 'wagmi';
import WhiteList from './WhiteList';
import { LoadingOutlined, CheckCircleOutlined } from '@ant-design/icons';
import { whitelistApi } from '../utils/request';

const { Title, Text } = Typography;
const { TabPane } = Tabs;

interface MintNFTProps {
    nftAddress: `0x${string}`;
    nftABI: any;
}

interface WhitelistData {
    tokenId: string;
    deadline: string;
    signature: string;
    nonce?: string;
}


const MintNFT = ({ nftAddress, nftABI }: MintNFTProps) => {
    const BASE_ERC721_ABI = nftABI;
    const { address, isConnected } = useAccount();
    const [mintLoading, setMintLoading] = useState(false);
    const [isWhitelisted, setIsWhitelisted] = useState<boolean | null>(null);
    const [isCheckingWhitelist, setIsCheckingWhitelist] = useState(false);
    const [mintSuccess, setMintSuccess] = useState(false);
    const [mintedTokenId, setMintedTokenId] = useState<string | null>(null);
    const config = useConfig();
    const [whitelistData, setWhitelistData] = useState<WhitelistData | null>(null);
    const { data: hash } = useWriteContract();
    const { writeContractAsync } = useWriteContract()
    
    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });


    // 获取 NFT 合约信息
    const { data: owner } = useReadContract({
        address: nftAddress,
        abi: BASE_ERC721_ABI,
        functionName: 'owner',
    });

    // 获取 NFT 合约信息
    const { data: nftName } = useReadContract({
        address: nftAddress,
        abi: BASE_ERC721_ABI,
        functionName: 'name',
    });

    const { data: nftSymbol } = useReadContract({
        address: nftAddress,
        abi: BASE_ERC721_ABI,
        functionName: 'symbol',
    });

    const { data: nextTokenId, refetch: nextTokenIdRefetch } = useReadContract({
        address: nftAddress,
        abi: BASE_ERC721_ABI,
        functionName: 'nextTokenId',
    });

    // 获取用户的nonce
    // const { data: userNonce, refetch: refetchNonce } = useReadContract({
    //     address: nftAddress,
    //     abi: BASE_ERC721_ABI,
    //     functionName: 'nonces',
    //     args: address ? [address] : undefined,
    // });

    // 获取用户拥有的 NFT 数量
    const { data: balanceOf, refetch: balanceOfRefetch } = useReadContract({
        address: nftAddress,
        abi: BASE_ERC721_ABI,
        functionName: 'balanceOf',
        args: address ? [address] : undefined,
    });

    // 检查白名单状态的函数
    const checkWhitelistStatus = async () => {
        if (!address) return;

        // 如果已经成功铸造，不要再检查白名单
        if (mintSuccess) return;

        try {
            setIsCheckingWhitelist(true);
            // 从API获取白名单数据，这应该包括签名、tokenId和deadline
            const data = await whitelistApi.getSignature(address) as any;
            console.log('White list response:', data);

            // 假设API返回格式包含signature、tokenId、deadline和nonce
            if (data?.signature) {
                const { signature, tokenId, deadline, nonce } = data;

                // 保存完整的白名单数据
                setWhitelistData({
                    signature: signature,
                    tokenId: tokenId || (nextTokenId ? nextTokenId.toString() : '0'),
                    deadline: deadline || Math.floor(Date.now() / 1000 + 86400 * 7).toString(),
                    nonce: nonce?.toString()
                });

                setIsWhitelisted(true);
            } else {
                setIsWhitelisted(false);
                setWhitelistData(null);
            }
        } catch (error) {
            console.error('Error checking whitelist status:', error);
            setIsWhitelisted(false);
            setWhitelistData(null);
        } finally {
            setIsCheckingWhitelist(false);
        }
    };

    // Check whitelist status on component mount and when address changes
    useEffect(() => {
        if (mintSuccess) return; // 如果已经成功铸造，不要再检查白名单
        checkWhitelistStatus();
    }, [address, nextTokenId, mintSuccess]);


    // 处理铸造 NFT (用白名单签名铸造)
    const handleMint = async () => {
        if (!isConnected || !address) {
            message.error('Please connect your wallet first');
            return;
        }

        if (!isWhitelisted || !whitelistData) {
            message.error('You are not whitelisted');
            return;
        }

        const { tokenId, deadline, signature } = whitelistData;

        if (!tokenId || !deadline || !signature) {
            message.error('Invalid whitelist data');
            return;
        }

        if (!signature.startsWith('0x')) {
            message.error('Invalid signature format');
            return;
        }

        try {
            setMintLoading(true);

            // 检查签名是否过期
            const deadlineValue = BigInt(deadline);
            const currentTime = BigInt(Math.floor(Date.now() / 1000));

            if (deadlineValue < currentTime) {
                throw new Error('Signature has expired');
            }

            // 确保所有参数都是有效的
            const tokenIdValue = BigInt(tokenId);

            // // 确保nonce正确 - 获取当前nonce
            // const currentNonce = userNonce || BigInt(0);
            
            // // 检查API返回的nonce是否与合约的当前nonce匹配
            // const apiNonce = whitelistData.nonce ? BigInt(whitelistData.nonce) : undefined;
            // if (apiNonce !== undefined && apiNonce !== currentNonce) {
            //     console.warn(`API nonce (${apiNonce}) doesn't match contract nonce (${currentNonce}). Using contract nonce.`);
            // }

            console.log('Minting with params:', {
                to: address,
                tokenId: tokenIdValue.toString(),
                deadline: deadlineValue.toString(),
                signature: signature,
                // nonce: currentNonce.toString()
            });
            
            // 确保调用者就是接收NFT的地址 (msg.sender == to)
            const hash: any = await writeContractAsync({
                address: nftAddress,
                abi: BASE_ERC721_ABI,
                functionName: 'mintWithSignature',
                args: [
                    address, // 接收者地址必须是当前连接的钱包地址
                    tokenIdValue, // tokenId需要转换为BigInt
                    deadlineValue, // 截止时间需要转换为BigInt
                    signature as `0x${string}`, // 签名
                ],
            });

            console.log('Transaction hash:', hash);

            if (!hash) {
                throw new Error('Transaction failed - no hash returned');
            }

            // 在这里不需要设置成功状态，useEffect 会处理
            // 当交易确认后，监听器和 useEffect 会更新界面状态
            // 铸造成功后，更新状态
            await whitelistApi.deleteSignature(address as `0x${string}`);

            if (whitelistData) {
                setMintedTokenId(whitelistData.tokenId);
            }
            setMintSuccess(true);
            // 尝试安全刷新数据
            try {
                nextTokenIdRefetch();
                balanceOfRefetch();
                // refetchNonce();
            } catch (e) {
                console.warn('Error refreshing data after successful mint:', e);
            }

        } catch (error) {
            console.error('Error minting NFT:', error);
            message.error('Failed to mint NFT: ' + (error as Error).message);
            setMintLoading(false); // 只在错误时重置加载状态
        }
    };

    // 渲染铸造成功界面
    const renderMintSuccess = () => {
        return (
            <Result
                icon={<CheckCircleOutlined style={{ color: '#52c41a' }} />}
                title="NFT Minted Successfully!"
                subTitle={mintedTokenId ? `Token ID: ${mintedTokenId}` : "Your NFT has been minted"}
                extra={[
                    <Button 
                        type="primary" 
                        key="view"
                        onClick={() => window.open(`https://testnets.opensea.io/assets/${nftAddress}/${mintedTokenId}`, '_blank')}
                    >
                        View on OpenSea
                    </Button>,
                    <Button 
                        key="reset" 
                        onClick={() => {
                            setMintSuccess(false);
                            setMintedTokenId(null);
                            checkWhitelistStatus(); 
                        }}
                    >
                        Mint Another
                    </Button>,
                ]}
            />
        );
    };

    // 渲染白名单铸造界面
    const renderWhitelistMintSection = () => {
        if (!isConnected) {
            return <Text>Please connect your wallet first</Text>;
        }

        // 如果铸造成功，显示成功界面
        if (mintSuccess) {
            return renderMintSuccess();
        }

        if (isCheckingWhitelist) {
            return (
                <div style={{ textAlign: 'center', padding: '20px 0' }}>
                    <Spin indicator={<LoadingOutlined style={{ fontSize: 24 }} spin />} />
                    <Text style={{ display: 'block', marginTop: 16 }}>Checking whitelist status...</Text>
                </div>
            );
        }

        if (isWhitelisted && whitelistData) {
            return (
                <Card style={{ backgroundColor: '#f6ffed', borderColor: '#b7eb8f' }}>
                    <Title level={3} style={{ color: '#389e0d', margin: 0, textAlign: "center", marginBottom: 24 }}>You have a whitelist</Title>

                    <Space direction="vertical" style={{ width: '100%' }}>
                        <Text strong>Reserved Token ID: {whitelistData.tokenId}</Text>
                        <Text>Deadline: {new Date(Number(whitelistData.deadline) * 1000).toLocaleString()}</Text>
                        {/* {userNonce !== undefined && userNonce !== null && (
                            <Text>Current Nonce: {userNonce.toString()}</Text>
                        )} */}
                        {whitelistData.nonce && (
                            <Text>Signature Nonce: {whitelistData.nonce}</Text>
                        )}
                        <Button
                            type="primary"
                            onClick={handleMint}
                            loading={mintLoading || isConfirming}
                            block
                        >
                            {isConfirming ? 'Confirming...' : 'Mint NFT'}
                        </Button>
                    </Space>
                </Card>
            );
        }

        return (
            <div style={{ textAlign: 'center', padding: '20px 0' }}>
                <Text>{`You are not on the whitelist for this NFT`}</Text>
            </div>
        );
    };

    return (
        <div>
            <Title level={3} style={{ margin: 0, textAlign: "center" }}>Mint NFT</Title>
            <Card style={{ maxWidth: 600, margin: '0 auto', marginTop: 24 }}>
                <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }}>
                    <Text>NFT Contract: {nftName as string} ({nftSymbol as string})</Text>
                    <Text>NFT Contract Address: {nftAddress as string}</Text>
                    <Text>NFT Contract Owner: {owner as string}</Text>
                    <Text>Next Token ID: {nextTokenId?.toString()}</Text>
                    {address && (
                        <Text>Your NFTs: {balanceOf?.toString()}</Text>
                    )}
                </Space>

                <Tabs defaultActiveKey="whitelist">
                    {/* 所有用户都能看到Mint Tab，但只有非Owner才能铸造 */}
                    <TabPane tab="Mint NFT" key="whitelist" >
                        {renderWhitelistMintSection()}
                    </TabPane>

                    {address === owner && (
                        <TabPane tab="Whitelist Generator" key="generator">
                            <WhiteList nftAddress={nftAddress} nftABI={BASE_ERC721_ABI} />
                        </TabPane>
                    )}
                </Tabs>
            </Card>
        </div>
    );
};

export default MintNFT;
