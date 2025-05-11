import { useState, useEffect, useRef } from 'react';
import { Card, Input, Button, Form, Select, message, Space, Typography, Tag, Table, Divider } from 'antd';
import { useAccount, useBalance, useWriteContract, useReadContract, useBlockNumber, useConfig, usePublicClient, useSwitchChain, useChainId } from 'wagmi';
import { parseEther, formatEther, GetLogsReturnType } from 'viem';
import { MYTOKEN_ADDRESS, MY_TOKEN_ABI, TOKEN_BANK_ABI, anvil, sepolia, getContractAddresses } from '@/config';
import ConnectWallet from './ConnectWallet';
// waitForTransactionReceipt: 监听交易是否上链成功
import { waitForTransactionReceipt } from 'wagmi/actions'

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

const getCuurentAllTokens = (chainId: number) => {
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
  // watch=false: 减少更新的频率
  const { data: blockNumber } = useBlockNumber({ watch: false })
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()
  const [currentAddresses, setCurrentAddresses] = useState(getContractAddresses(chainId))
  // const allTokens = [...DEFAULT_TOKENS];
  const [allTokens, setAllTokens] = useState(getCuurentAllTokens(chainId));

  const [form] = Form.useForm();
  const { address } = useAccount();
  const [selectedToken, setSelectedToken] = useState(DEFAULT_TOKENS[0]);
  const [inputAmount, setInputAmount] = useState('');
  const config = useConfig()
  console.log('config->', config);

  const [depositLoading, setDepositLoading] = useState(false)
  const [withdrawLoading, setWithdrawLoading] = useState(false)

  // 当链 ID 改变时更新合约地址
  useEffect(() => {
    setCurrentAddresses(getContractAddresses(chainId))
  }, [chainId])

  // Get ETH balance
  const { data: ethBalance, refetch: ethBalanceRefetch } = useBalance({
    address,
  });

  // Get token balance
  const { data: tokenBalance, refetch: tokenRefetch } = useReadContract({
    address: selectedToken.address !== 'ETH' ? (currentAddresses.MYTOKEN as `0x${string}`) : undefined,
    abi: MY_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // Get Token Bank balance
  const { data: bankBalance, refetch: bankRefetch } = useReadContract({
    address: currentAddresses.TOKEN_BANK as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: selectedToken.symbol === 'ETH' ? 'ethBalanceOf' : 'tokenBalanceOf',
    args: selectedToken.symbol === 'ETH' ? [address] : [currentAddresses.MYTOKEN, address],
  });

  // Get ETH total deposits
  const { data: totalEthDeposits, refetch: totalEthDepositsRefetch } = useReadContract({
    address: currentAddresses.TOKEN_BANK as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: 'totalEthDeposits',
    args: [],
  });
  // Get Token total deposits
  const { data: totalTokenDeposits, refetch: totalTokenDepositsRefetch } = useReadContract({
    address: currentAddresses.TOKEN_BANK as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: 'getTotalTokenDeposits',
    args: [currentAddresses.MYTOKEN],
  });

  // Deposit function
  // const { writeContract: deposit } = useWriteContract();
  const { writeContractAsync: depositAsync } = useWriteContract()

  // Withdraw function
  // const { writeContract: withdraw } = useWriteContract();
  const { writeContractAsync: withdrawAsync } = useWriteContract()

  const { writeContractAsync: approveAsync } = useWriteContract()

  const getDepositInfomation = () => {
    try {
      const amount = parseEther(inputAmount);
      let is_eth = selectedToken.symbol === 'ETH';

      // 验证参数
      if (amount <= 0n) {
        throw new Error('Amount must be greater than 0');
      }

      if (!is_eth && (!selectedToken.address || selectedToken.address === 'ETH')) {
        throw new Error('Invalid token address');
      }

      console.log('Deposit parameters:', {
        is_eth,
        tokenAddress: selectedToken.address,
        amount: amount.toString(),
        parsedAmount: formatEther(amount)
      });

      let result = {
        functionName: is_eth ? 'depositEth' : 'depositToken',
        args: is_eth ? [] : [selectedToken.address, amount],
        value: is_eth ? amount : 0n
      }

      console.log('Deposit function info:', result);
      return result;
    } catch (error) {
      console.error('Error preparing deposit:', error);
      throw error;
    }
  }

  const getWithdrawInfomation = () => {
    const amount = parseEther(inputAmount);
    let is_eth = selectedToken.symbol === 'ETH';
    let result = {
      functionName: is_eth ? 'withdrawEth' : 'withdrawToken',
      args: is_eth ? [amount] : [selectedToken.address, amount],
    }
    return result
  }
  const handleTokenApprove = async () => {
    try {
      // 验证代币合约地址
      if (!currentAddresses.MYTOKEN) {
        throw new Error('Token contract address not found');
      }

      // 先检查当前授权额度
      const allowance = await publicClient?.readContract({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'allowance',
        args: [address, currentAddresses.TOKEN_BANK]
      }) as bigint | undefined;

      const amount = parseEther(inputAmount);

      console.log('Current allowance check:', {
        allowance: allowance?.toString(),
        required: amount.toString(),
        hasEnoughAllowance: allowance && allowance >= amount
      });

      // 检查代币余额
      const balance = await publicClient?.readContract({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'balanceOf',
        args: [address]
      }) as bigint | undefined;

      console.log('Token balance check:', {
        balance: balance?.toString(),
        required: amount.toString(),
        hasEnoughBalance: balance && balance >= amount
      });

      if (!balance || balance < amount) {
        throw new Error(`Insufficient token balance. Required: ${formatEther(amount)}, Available: ${balance ? formatEther(balance) : '0'}`);
      }

      // 如果授权额度不足，需要重新授权
      if (!allowance || allowance < amount) {
        message.info('Approving token transfer...');
        console.log('Initiating token approval...');

        try {
          // 授权金额设置为最大，避免频繁授权
          const approveHash = await approveAsync({
            address: currentAddresses.MYTOKEN as `0x${string}`,
            abi: MY_TOKEN_ABI,
            functionName: 'approve',
            args: [currentAddresses.TOKEN_BANK, 2n ** 256n - 1n],
          });

          console.log('Approval transaction submitted:', {
            hash: approveHash,
            tokenAddress: currentAddresses.MYTOKEN,
            spender: currentAddresses.TOKEN_BANK
          });

          // 获取交易详情
          const tx = await publicClient?.getTransaction({ hash: approveHash });
          console.log('Approval transaction details:', {
            hash: approveHash,
            from: tx?.from,
            to: tx?.to,
            value: tx?.value.toString(),
            input: tx?.input
          });

          // 等待授权交易确认
          console.log('Waiting for approval transaction confirmation...');
          const receipt = await waitForTransactionReceipt(config, {
            hash: approveHash,
            timeout: 60000 // 设置 60 秒超时
          });

          console.log('Approval transaction receipt:', {
            status: receipt.status,
            blockNumber: receipt.blockNumber,
            gasUsed: receipt.gasUsed.toString(),
            effectiveGasPrice: receipt.effectiveGasPrice?.toString()
          });

          if (receipt.status === 'reverted') {
            // 尝试获取具体的错误信息
            const tx = await publicClient?.getTransaction({ hash: approveHash });
            console.error('Failed transaction details:', {
              hash: approveHash,
              from: tx?.from,
              to: tx?.to,
              value: tx?.value.toString(),
              input: tx?.input
            });

            // 尝试模拟交易以获取错误原因
            try {
              await publicClient?.simulateContract({
                address: currentAddresses.MYTOKEN as `0x${string}`,
                abi: MY_TOKEN_ABI,
                functionName: 'approve',
                args: [currentAddresses.TOKEN_BANK, 2n ** 256n - 1n],
                account: address
              });
            } catch (simError) {
              console.error('Transaction simulation error:', simError);
              throw new Error(`Approval simulation failed: ${(simError as Error).message}`);
            }

            throw new Error('Token approval transaction reverted');
          }

          // 验证授权是否成功
          const newAllowance = await publicClient?.readContract({
            address: currentAddresses.MYTOKEN as `0x${string}`,
            abi: MY_TOKEN_ABI,
            functionName: 'allowance',
            args: [address, currentAddresses.TOKEN_BANK]
          }) as bigint | undefined;

          console.log('New allowance after approval:', {
            newAllowance: newAllowance?.toString(),
            required: amount.toString(),
            isApproved: newAllowance && newAllowance >= amount
          });

          if (!newAllowance || newAllowance < amount) {
            throw new Error('Token approval verification failed');
          }

          message.success('Token approved successfully!');
        } catch (error) {
          console.error('Token approval process failed:', error);
          // 尝试获取更详细的错误信息
          if (error instanceof Error) {
            const errorMessage = error.message;
            if (errorMessage.includes('user rejected')) {
              message.error('Transaction was rejected by user');
            } else if (errorMessage.includes('insufficient funds')) {
              message.error('Insufficient funds for gas');
            } else if (errorMessage.includes('timeout')) {
              message.error('Transaction confirmation timeout');
            } else {
              message.error(`Token approval failed: ${errorMessage}`);
            }
          } else {
            message.error('Token approval failed with unknown error');
          }
          return;
        }
      }
    } catch (error) {
      console.error('Token approval check failed:', error);
      message.error('Token approval check failed: ' + (error as Error).message);
      return;
    }
  }

  const handleDeposit = async () => {
    try {
      setDepositLoading(true);

      // 验证输入
      if (!inputAmount || isNaN(Number(inputAmount)) || Number(inputAmount) <= 0) {
        throw new Error('Please enter a valid amount');
      }

      const { functionName, args, value } = getDepositInfomation();
      console.log('{ functionName, args, value }->', { functionName, args, value });

      const is_eth = selectedToken.symbol === 'ETH';

      // 验证合约地址
      console.log('Contract addresses check:', {
        chainId,
        tokenBankAddress: currentAddresses.TOKEN_BANK,
        tokenAddress: currentAddresses.MYTOKEN,
        isAnvil: chainId === anvil.id,
        isSepolia: chainId === sepolia.id
      });

      // 如果是 ERC20 token，先检查授权
      if (!is_eth) {
        handleTokenApprove();
      }

      // 在存款前再次验证授权
      const finalAllowance = await publicClient?.readContract({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'allowance',
        args: [address, currentAddresses.TOKEN_BANK]
      }) as bigint | undefined;

      const amount = parseEther(inputAmount);

      console.log('Final allowance check before deposit:', {
        allowance: finalAllowance?.toString(),
        required: amount.toString(),
        hasEnoughAllowance: finalAllowance && finalAllowance >= amount
      });

      if (!finalAllowance || finalAllowance < amount) {
        throw new Error('Insufficient token allowance after approval');
      }

      // 验证合约中的 token 余额
      const contractBalance = await publicClient?.readContract({
        address: currentAddresses.MYTOKEN as `0x${string}`,
        abi: MY_TOKEN_ABI,
        functionName: 'balanceOf',
        args: [currentAddresses.TOKEN_BANK]
      }) as bigint | undefined;

      console.log('Contract token balance check:', {
        contractBalance: contractBalance?.toString(),
        required: amount.toString(),
        hasEnoughBalance: contractBalance && contractBalance >= amount
      });

      // 模拟存款交易
      try {
        await publicClient?.simulateContract({
          address: currentAddresses.TOKEN_BANK as `0x${string}`,
          abi: TOKEN_BANK_ABI,
          functionName: 'depositToken',
          args: [currentAddresses.MYTOKEN, amount],
          account: address
        });
        console.log('Deposit simulation successful');
      } catch (simError) {
        console.error('Deposit simulation failed:', simError);
        throw new Error(`Deposit simulation failed: ${(simError as Error).message}`);
      }

      // 执行存款
      try {
        console.log('Executing deposit with args:', {
          functionName,
          args: args.map(arg => arg.toString()),
          value: value.toString(),
          tokenAddress: currentAddresses.MYTOKEN,
          bankAddress: currentAddresses.TOKEN_BANK,
          chainId
        });

        const hash = await depositAsync({
          address: currentAddresses.TOKEN_BANK as `0x${string}`,
          abi: TOKEN_BANK_ABI,
          functionName: functionName,
          args: args,
          value: value,
        });

        console.log('Deposit transaction submitted:', {
          hash,
          chainId,
          tokenBankAddress: currentAddresses.TOKEN_BANK,
          tokenAddress: currentAddresses.MYTOKEN
        });

        // 等待交易确认
        console.log('Waiting for deposit transaction confirmation...');
        const receipt = await waitForTransactionReceipt(config, {
          hash,
          timeout: 60000 // 60 秒超时
        });

        console.log('Deposit transaction receipt:', {
          status: receipt.status,
          blockNumber: receipt.blockNumber,
          gasUsed: receipt.gasUsed.toString(),
          effectiveGasPrice: receipt.effectiveGasPrice?.toString()
        });

        if (receipt.status === 'reverted') {
          // 获取交易详情
          const tx = await publicClient?.getTransaction({ hash });
          console.error('Failed deposit transaction details:', {
            hash,
            from: tx?.from,
            to: tx?.to,
            value: tx?.value.toString(),
            input: tx?.input,
            chainId
          });

          throw new Error('Deposit transaction reverted');
        }

        // 交易完成后更新所有余额
        await updateAllBalances();

        message.success('Deposit successful!');
        form.resetFields();
        setInputAmount('');
      } catch (error) {
        console.error('Deposit failed:', error);
        // 尝试解析具体的错误信息
        const errorMessage = (error as Error).message;
        if (errorMessage.includes('insufficient funds')) {
          message.error('Insufficient balance for deposit');
        } else if (errorMessage.includes('user rejected')) {
          message.error('Transaction was rejected');
        } else if (errorMessage.includes('execution reverted')) {
          // 获取更详细的错误信息
          const reason = errorMessage.includes('reason=')
            ? errorMessage.split('reason=')[1].split(',')[0]
            : 'Unknown reason';
          message.error(`Transaction failed: ${reason}`);
        } else {
          message.error('Deposit failed: ' + errorMessage);
        }
      }
    } catch (error) {
      console.error('Operation failed:', error);
      message.error('Operation failed: ' + (error as Error).message);
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

      await waitForTransactionReceipt(config, { hash });

      // 交易完成后更新所有余额
      await updateAllBalances();

      message.success('Withdraw successful!');
      setInputAmount('');
      form.resetFields();
    } catch (error) {
      console.error('Withdraw failed:', error);
      message.error('Withdraw failed: ' + (error as Error).message);
    } finally {
      setWithdrawLoading(false);
    }
  };


  // 获取所有存款用户的信息
  const [depositUsers, setDepositUsers] = useState<Array<{
    address: string;
    ethBalance: string;
    tokenBalance: string;
  }>>([]);

  const publicClient = usePublicClient();

  // 添加缓存相关的状态
  const lastUpdateBlockRef = useRef<bigint>(0n);
  const lastUpdateTimeRef = useRef<number>(0);
  const CACHE_DURATION = 30000; // 缓存时间 30 秒
  const MAX_BLOCKS = 100n; // 最多查询最近 100 个区块

  // 添加缓存状态
  const balanceCache = useRef<{
    ethBalance?: bigint;
    tokenBalance?: bigint;
    bankBalance?: bigint;
    totalEthDeposits?: bigint;
    totalTokenDeposits?: bigint;
    timestamp: number;
  }>({ timestamp: 0 });

  // 批量获取余额的函数
  const batchGetBalances = async () => {
    if (!publicClient || !address) return null;

    try {
      // 使用 multicall 批量请求
      const [ethBalance, tokenBalance, bankBalance, totalEthDeposits, totalTokenDeposits] = await Promise.all([
        // ETH 余额
        publicClient.getBalance({ address }),
        // Token 余额
        selectedToken.address !== 'ETH' ?
          publicClient.readContract({
            address: currentAddresses.MYTOKEN as `0x${string}`,
            abi: MY_TOKEN_ABI,
            functionName: 'balanceOf',
            args: [address]
          }) : Promise.resolve(0n),
        // Bank 余额
        publicClient.readContract({
          address: currentAddresses.TOKEN_BANK as `0x${string}`,
          abi: TOKEN_BANK_ABI,
          functionName: selectedToken.symbol === 'ETH' ? 'ethBalanceOf' : 'tokenBalanceOf',
          args: selectedToken.symbol === 'ETH' ? [address] : [currentAddresses.MYTOKEN, address]
        }),
        // Total ETH deposits
        publicClient.readContract({
          address: currentAddresses.TOKEN_BANK as `0x${string}`,
          abi: TOKEN_BANK_ABI,
          functionName: 'totalEthDeposits'
        }),
        // Total Token deposits
        publicClient.readContract({
          address: currentAddresses.TOKEN_BANK as `0x${string}`,
          abi: TOKEN_BANK_ABI,
          functionName: 'getTotalTokenDeposits',
          args: [currentAddresses.MYTOKEN]
        })
      ]);

      // 更新缓存
      balanceCache.current = {
        ethBalance: ethBalance as bigint,
        tokenBalance: tokenBalance as bigint,
        bankBalance: bankBalance as bigint,
        totalEthDeposits: totalEthDeposits as bigint,
        totalTokenDeposits: totalTokenDeposits as bigint,
        timestamp: Date.now()
      };

      return balanceCache.current;
    } catch (error) {
      console.error('Failed to batch get balances:', error);
      return null;
    }
  };

  // 优化后的更新余额函数
  const updateAllBalances = async () => {
    try {
      const now = Date.now();
      const currentBlock = await publicClient?.getBlockNumber();

      // 检查缓存是否有效（30秒内）
      if (
        balanceCache.current.timestamp &&
        now - balanceCache.current.timestamp < CACHE_DURATION &&
        currentBlock &&
        lastUpdateBlockRef.current &&
        currentBlock - lastUpdateBlockRef.current < 5n
      ) {
        return;
      }

      // 批量获取余额
      const balances = await batchGetBalances();
      if (!balances) return;

      // 更新状态
      if (balances.ethBalance !== undefined) {
        ethBalanceRefetch();
      }
      if (balances.tokenBalance !== undefined) {
        tokenRefetch();
      }
      if (balances.bankBalance !== undefined) {
        bankRefetch();
      }
      if (balances.totalEthDeposits !== undefined) {
        totalEthDepositsRefetch();
      }
      if (balances.totalTokenDeposits !== undefined) {
        totalTokenDepositsRefetch();
      }

      // 延迟加载存款用户信息
      setTimeout(() => {
        if (currentBlock) {
          fetchAllDeposits(currentBlock);
        }
      }, 1000);

      // 更新缓存时间戳和区块号
      if (currentBlock) {
        lastUpdateBlockRef.current = currentBlock;
        lastUpdateTimeRef.current = now;
      }
    } catch (error) {
      console.error('Failed to update balances:', error);
    }
  };

  // 获取所有存款用户的信息
  const fetchAllDeposits = async (currentBlock?: bigint) => {
    if (!publicClient || !currentBlock) return;
    
    try {
      // 计算起始区块（最多查询最近 100 个区块）
      const fromBlock = currentBlock > MAX_BLOCKS ? currentBlock - MAX_BLOCKS : 0n;
      
      // 定义事件过滤器
      const eventFilters = {
        address: currentAddresses.TOKEN_BANK as `0x${string}`,
        fromBlock,
        toBlock: currentBlock
      };

      // 分别获取每种类型的事件
      const [ethDepositLogs, tokenDepositLogs, ethWithdrawLogs, tokenWithdrawLogs] = await Promise.all([
        publicClient.getLogs({
          ...eventFilters,
          event: TOKEN_BANK_EVENTS.EthDeposit
        }),
        publicClient.getLogs({
          ...eventFilters,
          event: TOKEN_BANK_EVENTS.TokenDeposit
        }),
        publicClient.getLogs({
          ...eventFilters,
          event: TOKEN_BANK_EVENTS.EthWithdraw
        }),
        publicClient.getLogs({
          ...eventFilters,
          event: TOKEN_BANK_EVENTS.TokenWithdraw
        })
      ]);

      // 使用 Map 存储用户余额，提高查找效率
      const userBalances = new Map<string, { 
        ethBalance: bigint; 
        tokenBalance: bigint;
        lastUpdateBlock: bigint;
      }>();

      // 处理事件日志
      type TokenBankLog = GetLogsReturnType<typeof TOKEN_BANK_EVENTS.EthDeposit>[number] | 
                         GetLogsReturnType<typeof TOKEN_BANK_EVENTS.TokenDeposit>[number] |
                         GetLogsReturnType<typeof TOKEN_BANK_EVENTS.EthWithdraw>[number] |
                         GetLogsReturnType<typeof TOKEN_BANK_EVENTS.TokenWithdraw>[number];

      const processLog = (log: TokenBankLog) => {
        if (!log.blockNumber) return;

        // 根据事件类型处理不同的参数
        if (log.eventName === 'EthDeposit' || log.eventName === 'EthWithdraw') {
          const { user, amount } = log.args as { user: `0x${string}`; amount: bigint };
          if (!user || !amount) return;

          const current = userBalances.get(user) || { 
            ethBalance: 0n, 
            tokenBalance: 0n,
            lastUpdateBlock: log.blockNumber
          };

          // 如果事件区块号小于最后更新区块号，说明是旧事件，跳过
          if (log.blockNumber < current.lastUpdateBlock) {
            return;
          }

          if (log.eventName === 'EthDeposit') {
            userBalances.set(user, {
              ...current,
              ethBalance: current.ethBalance + amount,
              lastUpdateBlock: log.blockNumber
            });
          } else {
            // 确保余额不会变成负数
            const newBalance = current.ethBalance > amount ? 
              current.ethBalance - amount : 0n;
            userBalances.set(user, {
              ...current,
              ethBalance: newBalance,
              lastUpdateBlock: log.blockNumber
            });
          }
        } else if (log.eventName === 'TokenDeposit' || log.eventName === 'TokenWithdraw') {
          const { user, token, amount } = log.args as { 
            user: `0x${string}`; 
            token: `0x${string}`; 
            amount: bigint 
          };
          if (!user || !token || !amount) return;

          const current = userBalances.get(user) || { 
            ethBalance: 0n, 
            tokenBalance: 0n,
            lastUpdateBlock: log.blockNumber
          };

          // 如果事件区块号小于最后更新区块号，说明是旧事件，跳过
          if (log.blockNumber < current.lastUpdateBlock) {
            return;
          }

          if (log.eventName === 'TokenDeposit') {
            userBalances.set(user, {
              ...current,
              tokenBalance: current.tokenBalance + amount,
              lastUpdateBlock: log.blockNumber
            });
          } else {
            // 确保余额不会变成负数
            const newBalance = current.tokenBalance > amount ? 
              current.tokenBalance - amount : 0n;
            userBalances.set(user, {
              ...current,
              tokenBalance: newBalance,
              lastUpdateBlock: log.blockNumber
            });
          }
        }
      };

      // 合并并排序所有日志
      const allLogs = [
        ...ethDepositLogs,
        ...tokenDepositLogs,
        ...ethWithdrawLogs,
        ...tokenWithdrawLogs
      ] as TokenBankLog[];

      // 按区块号排序
      allLogs.sort((a, b) => Number(a.blockNumber! - b.blockNumber!));

      // 处理所有日志
      for (const log of allLogs) {
        try {
          processLog(log);
        } catch (error) {
          console.error(`Error processing log at block ${log.blockNumber}:`, error);
          continue;
        }
      }

      // 转换为数组格式，只保留有余额的用户
      const users = Array.from(userBalances.entries())
        .filter(([_, balances]) => balances.ethBalance > 0n || balances.tokenBalance > 0n)
        .map(([address, balances]) => ({
          address,
          ethBalance: formatEther(balances.ethBalance),
          tokenBalance: formatEther(balances.tokenBalance)
        }));

      // 按余额大小排序
      users.sort((a, b) => {
        const aTotal = Number(a.ethBalance) + Number(a.tokenBalance);
        const bTotal = Number(b.ethBalance) + Number(b.tokenBalance);
        return bTotal - aTotal;
      });

      setDepositUsers(users);
    } catch (error) {
      console.error('Failed to fetch deposits:', error);
      message.error('Failed to fetch deposit information');
    }
  };

  // 在区块更新时更新余额
  useEffect(() => {
    if (publicClient && blockNumber) {
      // 每 5 个区块更新一次，且距离上次更新超过 30 秒
      if (blockNumber % 5n === 0n && Date.now() - lastUpdateTimeRef.current > CACHE_DURATION) {
        updateAllBalances();
      }
    }
  }, [blockNumber, publicClient]);

  const columns = [
    {
      title: 'User Address',
      dataIndex: 'address',
      key: 'address',
    },
    {
      title: 'ETH Balance',
      dataIndex: 'ethBalance',
      key: 'ethBalance',
      render: (value: string) => `${value} ETH`,
    },
    {
      title: 'Token Balance',
      dataIndex: 'tokenBalance',
      key: 'tokenBalance',
      render: (value: string) => `${value} SNK`,
    },
  ];
  // 处理切换网络
  const handleSwitchNetwork = async (targetChainId: number) => {
    try {
      setDepositLoading(true) // 防止切换过程中的操作
      setWithdrawLoading(true)

      await switchChain({ chainId: targetChainId })

      // 等待网络切换完成
      await new Promise(resolve => setTimeout(resolve, 1000))

      // 验证切换后的地址
      const newAddresses = getContractAddresses(targetChainId)
      if (!newAddresses.TOKEN_BANK || !newAddresses.MYTOKEN) {
        throw new Error('Invalid contract addresses for selected network')
      }

      // 更新所有余额
      await updateAllBalances()

      message.success('Network switched successfully')
    } catch (error) {
      console.error('Failed to switch network:', error)
      message.error('Failed to switch network: ' + (error as Error).message)
    } finally {
      setDepositLoading(false)
      setWithdrawLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <Card style={{ maxWidth: 600, margin: '0 auto', marginTop: 24 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <Select
            value={chainId}
            onChange={handleSwitchNetwork}
            style={{ width: 120 }}
          >
            <Select.Option value={anvil.id}>Anvil</Select.Option>
            <Select.Option value={sepolia.id}>Sepolia</Select.Option>
          </Select>
          <Title level={3} style={{ margin: 0 }}>Token Bank</Title>
          <Space>
            <ConnectWallet />
          </Space>
        </div>

        <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }}>
          <Text>Your ETH Balance: {formatBalance(ethBalance?.value, 'ETH')}</Text>
          {selectedToken.address !== 'ETH' && tokenBalance !== undefined && (
            <Text>Your {selectedToken.symbol} Balance: {formatBalance(tokenBalance, selectedToken.symbol)}</Text>
          )}
          <Text>Bank Balance: {formatBalance(bankBalance, selectedToken.symbol)}</Text>
          <Divider />
          <Text strong>Total Deposits:</Text>
          <Text>Total ETH: {formatBalance(totalEthDeposits, 'ETH')}</Text>
          <Text>Total {DEFAULT_TOKENS[1].symbol}: {formatBalance(totalTokenDeposits, DEFAULT_TOKENS[1].symbol)}</Text>
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
            <Button loading={depositLoading} type="primary" onClick={() => form.validateFields().then(handleDeposit)}>
              Deposit
            </Button>
            <Button loading={withdrawLoading} onClick={() => form.validateFields().then(handleWithdraw)}>
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