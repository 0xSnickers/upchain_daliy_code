import { useState } from 'react';
import { Card, Button, Form, Input, message, Space, Typography, Select } from 'antd';
import { useAccount, useWriteContract, useReadContract, useConfig, useChainId } from 'wagmi';
import { waitForTransactionReceipt } from 'wagmi/actions';
import { anvil, sepolia, getContractAddresses } from '@/config';
import { BASE_ERC721_ABI } from '@/config';
import { isAddress } from 'viem'
const { Title, Text } = Typography;
const { Option } = Select;

interface MintNFTProps {
    nftAddress: `0x${string}`;
}

const MintNFT = ({ nftAddress }: MintNFTProps) => {
    const [form] = Form.useForm();
    const { address } = useAccount();
    const chainId = useChainId();
    const [mintLoading, setMintLoading] = useState(false);
    const [mintToAddress, setMintToAddress] = useState("");
    const config = useConfig();
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

    // 获取用户拥有的 NFT 数量
    const { data: balanceOf, refetch: balanceOfRefetch } = useReadContract({
        address: nftAddress,
        abi: BASE_ERC721_ABI,
        functionName: 'balanceOf',
        args: address ? [address] : undefined,
    });

    const { writeContractAsync: mintAsync } = useWriteContract();

    // 处理铸造 NFT
    const handleMint = async () => {
        if (!isAddress(mintToAddress)) {
            message.error('Please enter a right address!');
            return;
        }
        try {
            setMintLoading(true);

            if (!address) {
                throw new Error('Please connect your wallet first');
            }

            const hash = await mintAsync({
                address: nftAddress,
                abi: BASE_ERC721_ABI,
                functionName: 'mint',
                args: [mintToAddress],
            });

            const receipt = await waitForTransactionReceipt(config, {
                hash,
                timeout: 60000,
            });

            if (receipt.status === 'reverted') {
                throw new Error('Mint transaction reverted');
            }
            nextTokenIdRefetch()
            balanceOfRefetch()
            message.success('NFT minted successfully!');
            form.resetFields();
        } catch (error) {
            console.error('Mint failed:', error);
            message.error('Mint failed: ' + (error as Error).message);
        } finally {
            setMintLoading(false);
        }
    };

    return (
        <div>
            <Title level={3} style={{ margin: 0, textAlign: "center" }}>Mint NFT</Title>
            <Card style={{ maxWidth: 600, margin: '0 auto', marginTop: 24 }}>
                <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }}>
                    <Text>NFT Contract: {nftName as string} ({nftSymbol as string})</Text>
                    <Text>NFT Contract Owner: {owner as string}</Text>
                    <Text>Next Token ID: {nextTokenId?.toString()}</Text>
                    {address && (
                        <Text>Your NFTs: {balanceOf?.toString()}</Text>
                    )}
                </Space>

                <Form form={form} layout="vertical">
                    <Form.Item>
                        <Input placeholder="To Address" value={mintToAddress} onChange={(e) => { setMintToAddress(e.target.value) }} />
                    </Form.Item>
                    <Form.Item>
                        <Button
                            type="primary"
                            loading={mintLoading}
                            onClick={handleMint}
                            disabled={address != owner}
                            block
                        >
                            Mint NFT
                        </Button>
                    </Form.Item>
                </Form>
            </Card>
        </div>
    );
};

export default MintNFT;
