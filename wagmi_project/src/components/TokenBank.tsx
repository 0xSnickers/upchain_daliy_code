import { useState, useEffect } from 'react';
import { Card, Input, Button, Form, Select, message, Space, Typography, Tag, Table, Divider } from 'antd';
import { useAccount, useBalance, useWriteContract, useReadContract, useBlockNumber, useConfig, usePublicClient, useChainId } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { MYTOKEN_ADDRESS, MY_TOKEN_ABI, TOKEN_BANK_ABI, anvil, sepolia, getContractAddresses } from '@/config';
// waitForTransactionReceipt: 监听交易是否上链成功
import { waitForTransactionReceipt } from 'wagmi/actions'
import { useTokenBankBalances } from '@/hook/useTokenBankBalances';

const { Title, Text } = Typography;
const { Option } = Select;

// 格式化余额，保留4位小数
const formatBalance = (value: any, symbol: string = '') => {
  if (!value) return `0 ${symbol}`;
  const num = typeof value === 'string' ? value : formatEther(value);
  const formatted = Number(num).toFixed(4);
  return `${formatted} ${symbol}`;
};

// 预定义的代币列表
const DEFAULT_TOKENS = [
  {
    symbol: 'ETH',
    address: 'ETH',
    name: 'Ethereum',
    decimals: 18,
  },
  {
    symbol: 'SNK',
    address: MYTOKEN_ADDRESS,
    name: 'Snikers',
    decimals: 18,
  },
];

const getCurrentAllTokens = (chainId: number) => {
  let all_tokens = DEFAULT_TOKENS.map(v => v);
  all_tokens[1].address = getContractAddresses(chainId)?.MYTOKEN
  return all_tokens;
}

// 定义事件类型
type TokenBankEvent = {
  EthDeposit: {
    user: `0x${string}`;
    amount: bigint;
  };
  TokenDeposit: {
    user: `0x${string}`;
    token: `0x${string}`;
    amount: bigint;
  };
  EthWithdraw: {
    user: `0x${string}`;
    amount: bigint;
  };
  TokenWithdraw: {
    user: `0x${string}`;
    token: `0x${string}`;
    amount: bigint;
  };
};

// 定义事件 ABI
const TOKEN_BANK_EVENTS = {
  EthDeposit: {
    type: 'event',
    name: 'EthDeposit',
    inputs: [
      { type: 'address', name: 'user', indexed: true },
      { type: 'uint256', name: 'amount', indexed: false }
    ]
  } as const,
  TokenDeposit: {
    type: 'event',
    name: 'TokenDeposit',
    inputs: [
      { type: 'address', name: 'user', indexed: true },
      { type: 'address', name: 'token', indexed: true },
      { type: 'uint256', name: 'amount', indexed: false }
    ]
  } as const,
  EthWithdraw: {
    type: 'event',
    name: 'EthWithdraw',
    inputs: [
      { type: 'address', name: 'user', indexed: true },
      { type: 'uint256', name: 'amount', indexed: false }
    ]
  } as const,
  TokenWithdraw: {
    type: 'event',
    name: 'TokenWithdraw',
    inputs: [
      { type: 'address', name: 'user', indexed: true },
      { type: 'address', name: 'token', indexed: true },
      { type: 'uint256', name: 'amount', indexed: false }
    ]
  } as const
} as const;

const TokenBank = () => {
  const { data: blockNumber } = useBlockNumber({ watch: true })
  const chainId = useChainId()
  const [currentAddresses, setCurrentAddresses] = useState(getContractAddresses(chainId))
  const [allTokens, setAllTokens] = useState(getCurrentAllTokens(chainId));

  const [form] = Form.useForm();
  const { address } = useAccount();
  const [selectedToken, setSelectedToken] = useState(DEFAULT_TOKENS[0]);
  const [inputAmount, setInputAmount] = useState('');
  const config = useConfig()

  const [depositLoading, setDepositLoading] = useState(false)
  const [withdrawLoading, setWithdrawLoading] = useState(false)

  // 使用 useTokenBankBalances hook 获取所有余额
  const { 
    tokenBal, 
    bankBal, 
    totalDeposits, 
    loading: balancesLoading,
    refetch: refetchBalances 
  } = useTokenBankBalances({
    selectedToken,
    tokenAddress: currentAddresses.MYTOKEN as `0x${string}`,
    tokenBankAddress: currentAddresses.TOKEN_BANK as `0x${string}`,
    enabled: !!address,
    watch: true,
    chainId,
  });

  // Get ETH balance
  const { data: ethBalance, refetch: refetchEthBalance } = useBalance({
    address,
  });

  const { writeContractAsync: depositAsync } = useWriteContract()
  const { writeContractAsync: withdrawAsync } = useWriteContract()
  const { writeContractAsync: approveAsync } = useWriteContract()
  const publicClient = usePublicClient();

  // 当链 ID 改变时更新合约地址和余额
  useEffect(() => {
    const newAddresses = getContractAddresses(chainId);
    if (!newAddresses.TOKEN_BANK || !newAddresses.MYTOKEN) {
      message.error('Invalid contract addresses for selected network');
      return;
    }

    setCurrentAddresses(newAddresses);
    setAllTokens(getCurrentAllTokens(chainId));
    
    // 重置输入金额
    setInputAmount('');
    form.resetFields();
    
    // 刷新所有余额
    refetchBalances();
    refetchEthBalance();
  }, [chainId, form, refetchBalances, refetchEthBalance]);

  // 当区块号变化时刷新余额
  useEffect(() => {
    if (blockNumber) {
      refetchBalances();
      refetchEthBalance();
    }
  }, [blockNumber, refetchBalances, refetchEthBalance]);

  const getDepositInfomation = () => {
    try {
      const amount = parseEther(inputAmount);
      let is_eth = selectedToken.symbol === 'ETH';

      if (amount <= 0n) {
        throw new Error('Amount must be greater than 0');
      }

      if (!is_eth && (!selectedToken.address || selectedToken.address === 'ETH')) {
        throw new Error('Invalid token address');
      }

      return {
        functionName: is_eth ? 'depositEth' : 'depositToken',
        args: is_eth ? [] : [selectedToken.address, amount],
        value: is_eth ? amount : 0n
      }
    } catch (error) {
      console.error('Error preparing deposit:', error);
      throw error;
    }
  }

  const getWithdrawInfomation = () => {
    const amount = parseEther(inputAmount);
    let is_eth = selectedToken.symbol === 'ETH';
    return {
      functionName: is_eth ? 'withdrawEth' : 'withdrawToken',
      args: is_eth ? [amount] : [selectedToken.address, amount],
    }
  }

  const handleTokenApprove = async (amount: bigint): Promise<boolean> => {
    try {
      if (!currentAddresses.MYTOKEN) {
        throw new Error('Token contract address not found');
      }

      const allowance = await publicClient?.readContract({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'allowance',
        args: [address, currentAddresses.TOKEN_BANK]
      }) as bigint | undefined;

      if (allowance && allowance >= amount) {
        return true;
      }

      const balance = await publicClient?.readContract({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'balanceOf',
        args: [address]
      }) as bigint | undefined;

      if (!balance || balance < amount) {
        throw new Error(`Insufficient token balance. Required: ${formatEther(amount)}, Available: ${balance ? formatEther(balance) : '0'}`);
      }

      message.info('Approving token transfer...');

      const approveHash = await approveAsync({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'approve',
        args: [currentAddresses.TOKEN_BANK, 2n ** 256n - 1n],
      });

      const receipt = await waitForTransactionReceipt(config, { 
        hash: approveHash,
        timeout: 60000
      });

      if (receipt.status === 'reverted') {
        throw new Error('Token approval transaction reverted');
      }

      message.success('Token approved successfully!');
      return true;
    } catch (error) {
      console.error('Token approval failed:', error);
      message.error('Token approval failed: ' + (error as Error).message);
      return false;
    }
  };

  const handleDeposit = async () => {
    try {
      setDepositLoading(true);

      if (!inputAmount || isNaN(Number(inputAmount)) || Number(inputAmount) <= 0) {
        throw new Error('Please enter a valid amount');
      }

      const { functionName, args, value } = getDepositInfomation();
      const is_eth = selectedToken.symbol === 'ETH';
      const amount = parseEther(inputAmount);

      if (!is_eth) {
        const approved = await handleTokenApprove(amount);
        if (!approved) {
          return;
        }
      }

      const hash = await depositAsync({
        address: currentAddresses.TOKEN_BANK as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: functionName,
        args: args,
        value: value,
      });

      const receipt = await waitForTransactionReceipt(config, { 
        hash,
        timeout: 60000
      });

      if (receipt.status === 'reverted') {
        throw new Error('Deposit transaction reverted');
      }

      message.success('Deposit successful!');
      form.resetFields();
      setInputAmount('');
      refetchBalances();
    } catch (error) {
      console.error('Deposit failed:', error);
      message.error('Deposit failed: ' + (error as Error).message);
    } finally {
      setDepositLoading(false);
    }
  };

  const handleWithdraw = async () => {
    try {
      setWithdrawLoading(true);
      const { functionName, args } = getWithdrawInfomation();
      
      const hash = await withdrawAsync({
        address: currentAddresses.TOKEN_BANK as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: functionName,
        args: args,
      });
      
      const receipt = await waitForTransactionReceipt(config, { 
        hash,
        timeout: 60000
      });
      
      if (receipt.status === 'reverted') {
        throw new Error('Withdraw transaction reverted');
      }

      message.success('Withdraw successful!');
      setInputAmount('');
      form.resetFields();
      refetchBalances();
    } catch (error) {
      console.error('Withdraw failed:', error);
      message.error('Withdraw failed: ' + (error as Error).message);
    } finally {
      setWithdrawLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <Title level={3} style={{ margin: 0, textAlign:'center' }}>Token Bank</Title>
      <Card style={{ maxWidth: 600, margin: '10px auto' }}>
        <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }}>
          <Text>Current Network: {chainId === anvil.id ? 'Anvil' : chainId === sepolia.id ? 'Sepolia' : `Chain ${chainId}`}</Text>
          <Text>Your ETH Balance: {formatBalance(ethBalance?.value, 'ETH')}</Text>
          {selectedToken.address !== 'ETH' && tokenBal !== undefined && (
            <Text>Your {selectedToken.symbol} Balance: {formatBalance(tokenBal, selectedToken.symbol)}</Text>
          )}
          <Text>Bank Balance: {formatBalance(bankBal, selectedToken.symbol)}</Text>
          <Divider />
          <Text strong>Total Deposits:</Text>
          <Text>Total {selectedToken.symbol}: {formatBalance(totalDeposits, selectedToken.symbol)}</Text>
        </Space>

        <Form form={form} layout="vertical">
          <Form.Item label="Select Token">
            <Select
              value={selectedToken.address}
              onChange={(value) => {
                const token = allTokens.find(t => t.address === value);
                if (token) setSelectedToken(token);
              }}
              style={{ width: '100%' }}
            >
              {allTokens.map((token) => (
                <Option key={token.address} value={token.address}>
                  <Space>
                    <span>{token.symbol}</span>
                    <Tag color={token.address === 'ETH' ? 'blue' : 'green'}>
                      {token.name}
                    </Tag>
                  </Space>
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item label="Amount">
            <Input
              placeholder="Enter amount"
              value={inputAmount}
              onChange={(e) => setInputAmount(e.target.value)}
              addonAfter={`$${selectedToken.symbol}`}
            />
          </Form.Item>

          <Space>
            <Button 
              loading={depositLoading || balancesLoading} 
              type="primary" 
              onClick={() => form.validateFields().then(handleDeposit)}
            >
              Deposit
            </Button>
            <Button 
              loading={withdrawLoading || balancesLoading} 
              onClick={() => form.validateFields().then(handleWithdraw)}
            >
              Withdraw
            </Button>
          </Space>
        </Form>
      </Card>
      {/* 
      <Card style={{ margin: '0 auto', marginTop: 50 }}>
        <Title level={3}>All Deposits</Title>
        <Table
          dataSource={depositUsers}
          columns={columns}
          rowKey="address"
          pagination={{ pageSize: 5 }}
        />
      </Card> */}
    </div>
  );
};

export default TokenBank;