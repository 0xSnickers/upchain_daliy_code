import { useState, useEffect } from 'react';
import { Card, Button, Form, Input, message, Space, Typography, Select, Table, Tag, Modal, Row, Col, Divider } from 'antd';
import { useAccount, useWriteContract, useReadContract, useConfig, useChainId, useBalance, usePublicClient, useSignTypedData } from 'wagmi';
import { waitForTransactionReceipt } from 'wagmi/actions';
import { parseEther, formatEther } from 'viem';
import TOKEN_BANK_WITH_ERC20_ABI from '@/abi/TokenBankWithERC20Token.json'
import ERC20_ABI from '@/abi/PermitToken.json'
import PERMIT2_ABI from '@/abi/Permit2.json'
// import ERC20_ABI from '@/abi/OldToken.json'
import {getContractAddresses} from '@/config'
const { Title, Text } = Typography;
const { Option } = Select;

interface TokenInfo {
  address: `0x${string}`;
  symbol: string;
  name: string;
  decimals: number;
}

const TokenBankWithERC20 = () => {
  const [form] = Form.useForm();
  const { address } = useAccount();
  const chainId = useChainId();
  const [depositLoading, setDepositLoading] = useState(false);
  const [withdrawLoading, setWithdrawLoading] = useState(false);
  const [permitLoading, setPermitLoading] = useState(false);
  const [permit2Loading, setPermit2Loading] = useState(false);
  const [selectedToken, setSelectedToken] = useState<TokenInfo | null>(null);
  const [customTokenAddress, setCustomTokenAddress] = useState('');
  const [tokenList, setTokenList] = useState<TokenInfo[]>([]);
  const config = useConfig();
  const publicClient = usePublicClient();
  const { signTypedDataAsync } = useSignTypedData();

  // TokenBank 合约地址
  const tokenBankAddress = getContractAddresses(chainId)?.TOKEN_BANK_WITH_ERC20TOKEN as `0x${string}`;
  

  // 获取用户 ETH 余额
  const { data: ethBalance } = useBalance({
    address,
  });

  // 获取 Token 余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: selectedToken?.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) ;

  // 获取银行中的 Token 余额
  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    address: tokenBankAddress,
    abi: TOKEN_BANK_WITH_ERC20_ABI,
    functionName: 'balanceOf',
    args: address && selectedToken?.address ? [address, selectedToken.address] : undefined,
  });

  // 获取总存款
  const { data: totalDeposits } = useReadContract({
    address: tokenBankAddress,
    abi: TOKEN_BANK_WITH_ERC20_ABI,
    functionName: 'totalDeposits',
    args: selectedToken?.address ? [selectedToken.address] : undefined,
  });

  const { writeContractAsync: depositAsync } = useWriteContract();
  const { writeContractAsync: withdrawAsync } = useWriteContract();
  const { writeContractAsync: permitDepositAsync } = useWriteContract();
  const { writeContractAsync: approveAsync } = useWriteContract();

  // Permit2 合约地址
  const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3' as `0x${string}`;

  // 从 localStorage 加载保存的 Token 列表
  useEffect(() => {
    const loadSavedTokens = async () => {
      try {
        const savedTokens = localStorage.getItem('tokenBankTokens');
        if (savedTokens) {
          const tokens: TokenInfo[] = JSON.parse(savedTokens);
          // 验证每个 token 是否仍然有效
          const validTokens = await Promise.all(
            tokens.map(async (token) => {
              try {
                // 尝试读取 token 信息来验证其有效性
                await publicClient?.readContract({
                  address: token.address,
                  abi: ERC20_ABI,
                  functionName: 'symbol',
                });
                return token;
              } catch (error) {
                console.error(`Invalid token ${token.address}:`, error);
                return null;
              }
            })
          );
          const filteredTokens = validTokens.filter((token): token is TokenInfo => token !== null);
          setTokenList(filteredTokens);
          // 更新 localStorage 中的 token 列表
          localStorage.setItem('tokenBankTokens', JSON.stringify(filteredTokens));
        }
      } catch (error) {
        console.error('Error loading saved tokens:', error);
      }
    };

    loadSavedTokens();
  }, [publicClient]);

  // 保存 Token 列表到 localStorage
  const saveTokensToStorage = (tokens: TokenInfo[]) => {
    try {
      localStorage.setItem('tokenBankTokens', JSON.stringify(tokens));
    } catch (error) {
      console.error('Error saving tokens to localStorage:', error);
    }
  };

  // 添加自定义 Token
  const handleAddToken = async () => {
    try {
      if (!customTokenAddress) {
        message.error('Please enter token address');
        return;
      }

      const formattedAddress = customTokenAddress as `0x${string}`;

      // 检查 Token 是否已存在
      if (tokenList.some(token => token.address.toLowerCase() === formattedAddress.toLowerCase())) {
        message.error('Token already exists');
        return;
      }

      // 验证地址
      if (!formattedAddress.startsWith('0x') || formattedAddress.length !== 42) {
        message.error('Invalid token address format');
        return;
      }

      console.log('Adding token with address:', formattedAddress);

      try {
        // 尝试调用 token 的基本方法来验证它是否是 ERC20 token
        await publicClient?.readContract({
          address: formattedAddress,
          abi: ERC20_ABI,
          functionName: 'totalSupply',
        });

        // 获取 Token 信息
        const [symbol, name, decimals] = await Promise.all([
          publicClient?.readContract({
            address: formattedAddress,
            abi: ERC20_ABI,
            functionName: 'symbol',
          }),
          publicClient?.readContract({
            address: formattedAddress,
            abi: ERC20_ABI,
            functionName: 'name',
          }),
          publicClient?.readContract({
            address: formattedAddress,
            abi: ERC20_ABI,
            functionName: 'decimals',
          }),
        ]);

        console.log('Token info:', { symbol, name, decimals });

        const newToken: TokenInfo = {
          address: formattedAddress,
          symbol: symbol as string,
          name: name as string,
          decimals: Number(decimals),
        };

        const updatedTokenList = [...tokenList, newToken];
        setTokenList(updatedTokenList);
        setSelectedToken(newToken);
        setCustomTokenAddress('');
        // 保存到 localStorage
        saveTokensToStorage(updatedTokenList);
        message.success('Token added successfully');
      } catch (error) {
        console.error('Token validation error:', error);
        message.error('Invalid ERC20 token address: ' + (error as Error).message);
      }
    } catch (error) {
      console.error('Error adding token:', error);
      message.error('Failed to add token: ' + (error as Error).message);
    }
  };

  // 删除 Token
  const handleRemoveToken = (tokenAddress: string) => {
    const updatedTokenList = tokenList.filter(token => token.address !== tokenAddress);
    setTokenList(updatedTokenList);
    if (selectedToken?.address === tokenAddress) {
      setSelectedToken(null);
    }
    // 更新 localStorage
    saveTokensToStorage(updatedTokenList);
    message.success('Token removed successfully');
  };

  // 处理存款
  const handleDeposit = async (values: { amount: string }) => {
    try {
      setDepositLoading(true);

      if (!address || !selectedToken) {
        throw new Error('Please connect your wallet and select a token');
      }

      const amount = parseEther(values.amount);
      const tokenAddress = selectedToken.address;

      // 打印地址信息进行调试
      console.log('Debug addresses:');
      console.log('- TokenBank address:', tokenBankAddress);
      console.log('- Selected token address:', tokenAddress);
      console.log('- User address:', address);

      try {
        // 检查 Token 是否已授权给银行合约
        const allowance = await publicClient?.readContract({
          address: tokenAddress, // 使用 Token 合约地址
          abi: ERC20_ABI,
          functionName: 'allowance',
          args: [address, tokenBankAddress], // token owner, spender
        }) as bigint;

        console.log('Current allowance:', allowance.toString());

        if (!allowance || allowance < amount) {
          message.info('Approving token transfer...');
          // 在 Token 合约上调用 approve
          const approveHash = await approveAsync({
            address: tokenAddress, // 使用 Token 合约地址，确保这是正确的 ERC20 代币地址
            abi: ERC20_ABI,
            functionName: 'approve',
            args: [tokenBankAddress, amount],
          });

          await waitForTransactionReceipt(config, {
            hash: approveHash,
            timeout: 60000,
          });
          
          console.log('Approval successful');
        }
      } catch (error) {
        console.error('Error checking or giving allowance:', error);
        throw new Error('Failed to approve token transfer: ' + (error as Error).message);
      }

      // 在 TokenBank 合约上调用 deposit
      const hash = await depositAsync({
        address: tokenBankAddress, // 使用 TokenBank 合约地址
        abi: TOKEN_BANK_WITH_ERC20_ABI,
        functionName: 'deposit',
        args: [tokenAddress, amount],
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash,
        timeout: 60000,
      });

      if (receipt.status === 'reverted') {
        throw new Error('Deposit transaction reverted');
      }

      message.success('Deposit successful!');
      form.resetFields();
      refetchTokenBalance();
      refetchBankBalance();
    } catch (error) {
      console.error('Deposit failed:', error);
      message.error('Deposit failed: ' + (error as Error).message);
    } finally {
      setDepositLoading(false);
    }
  };

  // 处理取款
  const handleWithdraw = async (values: { amount: string }) => {
    try {
      setWithdrawLoading(true);

      if (!address || !selectedToken) {
        throw new Error('Please connect your wallet and select a token');
      }

      const amount = parseEther(values.amount);
      const tokenAddress = selectedToken.address;

      // 在 TokenBank 合约上调用 withdraw
      const hash = await withdrawAsync({
        address: tokenBankAddress,
        abi: TOKEN_BANK_WITH_ERC20_ABI,
        functionName: 'withdraw',
        args: [tokenAddress, amount],
      });

      const receipt = await waitForTransactionReceipt(config, {
        hash,
        timeout: 60000,
      });

      if (receipt.status === 'reverted') {
        throw new Error('Withdraw transaction reverted');
      }

      message.success('Withdraw successful!');
      form.resetFields();
      refetchTokenBalance();
      refetchBankBalance();
    } catch (error) {
      console.error('Withdraw failed:', error);
      message.error('Withdraw failed: ' + (error as Error).message);
    } finally {
      setWithdrawLoading(false);
    }
  };

  // 处理 Permit 存款
  const handlePermitDeposit = async (values: { amount: string }) => {
    let error_message = '';

    try {
      setPermitLoading(true);

      if (!address || !selectedToken) {
        throw new Error('Please connect your wallet and select a token');
      }

      const amount = parseEther(values.amount);
      const tokenAddress = selectedToken.address;
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now

      console.log('Debug addresses:');
      console.log('- TokenBank address:', tokenBankAddress);
      console.log('- Selected token address:', tokenAddress);
      console.log('- User address:', address);
      try {
        // 获取 token 元数据
        const [tokenName, nonce] = await Promise.all([
          publicClient?.readContract({
            address: tokenAddress,
            abi: ERC20_ABI,
            functionName: 'name',
          }),
          publicClient?.readContract({
            address: tokenAddress,
            abi: ERC20_ABI,
            functionName: 'nonces',
            args: [address],
          }),
        ]);

        console.log('Token metadata:', { tokenName, nonce });

        if (!tokenName) {
          throw new Error('Failed to get token name');
        }

        message.loading('Preparing to sign permit...', 0);

        // 构建 permit 数据
        const permitData = {
          owner: address,
          spender: tokenBankAddress,
          value: amount,
          nonce: nonce as bigint,
          deadline,
        };

        // 构建完整的签名数据
        const typedData = {
          domain: {
            name: tokenName as string,
            version: '1',
            chainId: BigInt(chainId),
            verifyingContract: tokenAddress,
          },
          types: {
            Permit: [
              { name: 'owner', type: 'address' },
              { name: 'spender', type: 'address' },
              { name: 'value', type: 'uint256' },
              { name: 'nonce', type: 'uint256' },
              { name: 'deadline', type: 'uint256' },
            ],
          },
          primaryType: 'Permit' as const,
          message: permitData,
        };

        console.log('Typed data for signature:', typedData);
        
        message.loading('Requesting signature from wallet...', 0);

        // 使用 wagmi 的 signTypedDataAsync 进行签名
        const signature = await signTypedDataAsync({
          domain: {
            name: tokenName as string,
            version: '1',
            chainId: BigInt(chainId),
            verifyingContract: tokenAddress,
          },
          types: {
            Permit: [
              { name: 'owner', type: 'address' },
              { name: 'spender', type: 'address' },
              { name: 'value', type: 'uint256' },
              { name: 'nonce', type: 'uint256' },
              { name: 'deadline', type: 'uint256' },
            ],
          },
          primaryType: 'Permit' as const,
          message: {
            owner: address,
            spender: tokenBankAddress,
            value: amount,
            nonce: nonce as bigint,
            deadline,
          },
        });

        if (!signature) {
          throw new Error('Failed to get signature');
        }

        console.log('Signature received:', signature);

        // 解析签名
        const r = signature.slice(0, 66);
        const s = '0x' + signature.slice(66, 130);
        const v = parseInt(signature.slice(130, 132), 16);

        console.log('Parsed signature:', { r, s, v });
        message.loading('Executing permit deposit...', 0);

        // 调用合约的 permitDeposit 方法
        const hash = await permitDepositAsync({
          address: tokenBankAddress,
          abi: TOKEN_BANK_WITH_ERC20_ABI,
          functionName: 'permitDeposit',
          args: [
            tokenAddress,
            amount,
            deadline,
            v,
            r,
            s,
          ],
        });

        const receipt = await waitForTransactionReceipt(config, {
          hash,
          timeout: 60000,
        });

        if (receipt.status === 'reverted') {
          throw new Error('Permit deposit transaction reverted');
        }

        message.destroy();
        message.success('Permit deposit successful!');
        form.resetFields();
        refetchTokenBalance();
        refetchBankBalance();
      } catch (error) {
        // message.destroy();
        console.error('Error during permit deposit:', error);
        if (error instanceof Error) {
          error_message = error.message;
          if (error.message.includes('User rejected')) {
            message.error('Transaction rejected by user');
          } else if (error.message.includes('insufficient funds')) {
            message.error('Insufficient token balance');
          } else if (error.message.includes('expired')) {
            message.error('Permit expired. Please try again.');
          } else if (error.message.includes('invalid signature')) {
            message.error('Invalid signature. Please try again.');
          } else {
            message.error('Error during permit deposit: ' + error.message);
          }
        } else {
          message.error('Error during permit deposit: ' + JSON.stringify(error));
        }
        // throw error;
      }
    } catch (error) {
      console.error('Permit deposit failed:', error);
      
      message.error('Permit deposit failed: ' + (error instanceof Error ? error.message : JSON.stringify(error)));
    } finally {
    
      setPermitLoading(false);
      // message.destroy();
    }
  };
  function findAvailableNonce(bitmap: bigint): bigint {
    for (let i = 0n; i < 256n; i++) {
      if (((bitmap >> i) & 1n) === 0n) return i;
    }
    throw new Error('All 256 nonces used');
  }
  // 处理 Permit2 存款
  const handlePermit2Deposit = async (values: { amount: string }) => {
    try {
      setPermit2Loading(true);

      if (!address || !selectedToken) {
        throw new Error('Please connect your wallet and select a token');
      }

      const amount = parseEther(values.amount);
      const tokenAddress = selectedToken.address;
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now

      console.log('Debug addresses:');
      console.log('- TokenBank address:', tokenBankAddress);
      console.log('- Selected token address:', tokenAddress);
      console.log('- User address:', address);
      console.log('- Permit2 address:', PERMIT2_ADDRESS);

      try {
        // 首先检查 Token 是否支持 Permit
        const hasPermit = await publicClient?.readContract({
          address: tokenAddress,
          abi: ERC20_ABI,
          functionName: 'nonces',
          args: [address],
        }).then(() => true).catch(() => false);

        if (hasPermit) {
          message.info('Token supports Permit, using Permit flow...');
          return handlePermitDeposit(values);
        }

        message.info('Token does not support Permit, using Permit2 flow...');

        // 获取 token 元数据和 nonce bitmap
        const [tokenName, nonceBitmap] = await Promise.all([
          publicClient?.readContract({
            address: tokenAddress,
            abi: ERC20_ABI,
            functionName: 'name',
          }),
          publicClient?.readContract({
            address: PERMIT2_ADDRESS,
            abi: PERMIT2_ABI,
            functionName: 'nonceBitmap',
            args: [address, 0],
          }),
        ]) as [string, bigint];

        console.log('Token metadata:', { tokenName, nonceBitmap });

        if (!tokenName) {
          throw new Error('Failed to get token name');
        }

        // 简化 nonce 处理，直接使用 wordPos 和 bitPos
        const wordPos = 0n;
        const bitPos = 0n;
        
        // 检查该 nonce 是否已使用
        const isUsed = (nonceBitmap & (1n << bitPos)) !== 0n;
        if (isUsed) {
          throw new Error('Nonce is already used');
        }

        console.log('Using nonce position:', { wordPos, bitPos });

        // 检查并授权 Permit2 合约
        const permit2Allowance = await publicClient?.readContract({
          address: tokenAddress,
          abi: ERC20_ABI,
          functionName: 'allowance',
          args: [address, PERMIT2_ADDRESS],
        }) as bigint;

        console.log('Current Permit2 allowance:', permit2Allowance.toString());

        // 确保 Permit2 合约有足够的授权
        if (!permit2Allowance || permit2Allowance < amount) {
          message.info('Approving token transfer to Permit2...');
          
          try {
            // 先重置授权
            const resetHash = await approveAsync({
              address: tokenAddress,
              abi: ERC20_ABI,
              functionName: 'approve',
              args: [PERMIT2_ADDRESS, 0n],
            });

            await waitForTransactionReceipt(config, {
              hash: resetHash,
              timeout: 60000,
            });

            // 然后设置新的授权
            const approveHash = await approveAsync({
              address: tokenAddress,
              abi: ERC20_ABI,
              functionName: 'approve',
              args: [PERMIT2_ADDRESS, amount], // 只授权需要的金额
            });

            await waitForTransactionReceipt(config, {
              hash: approveHash,
              timeout: 60000,
            });

            // 验证授权是否成功
            const newAllowance = await publicClient?.readContract({
              address: tokenAddress,
              abi: ERC20_ABI,
              functionName: 'allowance',
              args: [address, PERMIT2_ADDRESS],
            }) as bigint;

            console.log('New Permit2 allowance:', newAllowance.toString());

            if (newAllowance < amount) {
              throw new Error('Failed to approve Permit2');
            }
            
            console.log('Permit2 approval successful');
          } catch (error) {
            console.error('Error during Permit2 approval:', error);
            throw new Error('Failed to approve Permit2: ' + (error as Error).message);
          }
        }

        message.loading('Preparing to sign permit2...', 0);

        // 构建 permit2 数据
        const permit2Data = {
          permitted: {
            token: tokenAddress,
            amount: amount,
          },
          nonce: bitPos, // 使用 bitPos 作为 nonce
          deadline: deadline,
        };

        // 构建 transfer details
        const transferDetails = {
          to: tokenBankAddress,
          requestedAmount: amount,
        };

        // 构建完整的签名数据
        const typedData = {
          domain: {
            name: 'Permit2',
            version: '1',
            chainId: BigInt(chainId),
            verifyingContract: PERMIT2_ADDRESS,
          },
          types: {
            TokenPermissions: [
              { name: 'token', type: 'address' },
              { name: 'amount', type: 'uint256' },
            ],
            PermitTransferFrom: [
              { name: 'permitted', type: 'TokenPermissions' },
              { name: 'nonce', type: 'uint256' },
              { name: 'deadline', type: 'uint256' },
            ],
          },
          primaryType: 'PermitTransferFrom' as const,
          message: permit2Data,
        };

        // 获取 domain separator 进行验证
        const domainSeparator = await publicClient?.readContract({
          address: PERMIT2_ADDRESS,
          abi: PERMIT2_ABI,
          functionName: 'DOMAIN_SEPARATOR',
        });

        console.log('Domain separator from contract:', domainSeparator);

        // 使用 wagmi 的 signTypedDataAsync 进行签名
        const signature = await signTypedDataAsync({
          domain: typedData.domain,
          types: typedData.types,
          primaryType: typedData.primaryType,
          message: permit2Data,
        });

        if (!signature) {
          throw new Error('Failed to get signature');
        }

        // 验证签名长度
        if (signature.length !== 132) {
          console.warn('Unexpected signature length:', signature.length);
        }

        // 解析签名
        const r = signature.slice(0, 66);
        const s = '0x' + signature.slice(66, 130);
        const v = parseInt(signature.slice(130, 132), 16);

        console.log('Parsed signature:', { r, s, v });

        // 添加详细的调试信息
        console.log('Final parameters:', {
          permit: {
            ...permit2Data,
            permitted: {
              token: permit2Data.permitted.token.toLowerCase(),
              amount: permit2Data.permitted.amount.toString(),
            },
            nonce: permit2Data.nonce.toString(),
            deadline: permit2Data.deadline.toString(),
          },
          transferDetails: {
            to: transferDetails.to.toLowerCase(),
            requestedAmount: transferDetails.requestedAmount.toString(),
          },
          owner: address.toLowerCase(),
          signature,
        });

        // 调用 TokenBank 的 depositWithPermit2 方法
        const hash = await permitDepositAsync({
          address: tokenBankAddress,
          abi: TOKEN_BANK_WITH_ERC20_ABI,
          functionName: 'depositWithPermit2',
          args: [
            permit2Data,
            transferDetails,
            signature,
          ],
        });

        console.log('Transaction hash:', hash);
        console.log('Raw transaction data:', {
          permit: permit2Data,
          transferDetails,
          signature,
        });

        const receipt = await waitForTransactionReceipt(config, {
          hash,
          timeout: 60000,
        });

        if (receipt.status === 'reverted') {
          // 尝试获取更详细的错误信息
          try {
            const tx = await publicClient?.getTransaction({ hash });
            console.log('Failed transaction:', tx);
            
            // 尝试解码错误
            const error = await publicClient?.simulateContract({
              address: tokenBankAddress,
              abi: TOKEN_BANK_WITH_ERC20_ABI,
              functionName: 'depositWithPermit2',
              args: [
                permit2Data,
                transferDetails,
                signature,
              ],
              account: address,
            });
            console.log('Simulation error:', error);
          } catch (simError) {
            console.error('Error getting detailed error info:', simError);
          }
          throw new Error('Permit2 deposit transaction reverted');
        }

        message.destroy();
        message.success('Permit2 deposit successful!');
        form.resetFields();
        refetchTokenBalance();
        refetchBankBalance();
      } catch (error) {
        message.destroy();
        console.error('Error during permit2 deposit:', error);
        if (error instanceof Error) {
          if (error.message.includes('User rejected')) {
            message.error('Transaction rejected by user');
          } else if (error.message.includes('insufficient funds')) {
            message.error('Insufficient token balance');
          } else if (error.message.includes('expired')) {
            message.error('Permit2 expired. Please try again.');
          } else if (error.message.includes('invalid signature')) {
            message.error('Invalid signature. Please try again.');
          } else {
            message.error('Error during permit2 deposit: ' + error.message);
          }
        } else {
          message.error('Error during permit2 deposit: ' + JSON.stringify(error));
        }
        throw error;
      }
    } catch (error) {
      console.error('Permit2 deposit failed:', error);
      message.error('Permit2 deposit failed: ' + (error instanceof Error ? error.message : JSON.stringify(error)));
    } finally {
      setPermit2Loading(false);
      message.destroy();
    }
  };

  return (
    <div className="space-y-6">
      <Card style={{ maxWidth: 600, margin: '0 auto', marginTop: 24 }}>
        <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }}>
          <Text>Current Network: Chain {chainId}</Text>
          {address && (
            <Text>Your ETH Balance: {formatEther(ethBalance?.value || 0n)} ETH</Text>
          )}
          {selectedToken && (
            <>
              <Text>Selected Token: {selectedToken.name} ({selectedToken.symbol})</Text>
              <Text>Your Token Balance: {tokenBalance ? formatEther(tokenBalance as bigint) : '0'} {selectedToken.symbol}</Text>
              <Text>Bank Balance: {bankBalance ? formatEther(bankBalance as bigint) : '0'} {selectedToken.symbol}</Text>
              <Text>Total Deposits: {totalDeposits ? formatEther(totalDeposits as bigint) : '0'} {selectedToken.symbol}</Text>
            </>
          )}
        </Space>

        <Divider>Add Custom Token</Divider>
        <Space>
          <Input
            placeholder="Enter token address"
            value={customTokenAddress}
            onChange={(e) => setCustomTokenAddress(e.target.value)}
            style={{ width: 300 }}
          />
          <Button type="primary" onClick={handleAddToken}>
            Add Token
          </Button>
        </Space>

        <Divider>Select Token</Divider>
        <Space direction="vertical" style={{ width: '100%' }}>
          <Select
            style={{ width: '100%' }}
            placeholder="Select a token"
            value={selectedToken?.address}
            onChange={(value) => {
              const token = tokenList.find(t => t.address === value);
              if (token) setSelectedToken(token);
            }}
          >
            {tokenList.map((token) => (
              <Option key={token.address} value={token.address}>
                {token.name} ({token.symbol})
              </Option>
            ))}
          </Select>
          {selectedToken && (
            <Button 
              danger 
              size="small" 
              onClick={() => handleRemoveToken(selectedToken.address)}
            >
              Remove Token
            </Button>
          )}
        </Space>

        {selectedToken && (
          <>
            <Divider>Deposit/Withdraw</Divider>
            <Form
              form={form}
              layout="vertical"
              onFinish={handleDeposit}
            >
              <Form.Item
                label="Amount"
                name="amount"
                rules={[{ required: true, message: 'Please input the amount!' }]}
              >
                <Input
                  placeholder={`Enter amount in ${selectedToken.symbol}`}
                  addonAfter={selectedToken.symbol}
                />
              </Form.Item>

              <Space>
                <Button
                  type="primary"
                  htmlType="submit"
                  loading={depositLoading}
                >
                  Deposit
                </Button>
           
                <Button
                  onClick={() => form.validateFields().then(handlePermitDeposit)}
                  loading={permitLoading}
                  type="primary"
                >
                  Deposit with Permit
                </Button>

                <Button
                  onClick={() => form.validateFields().then(handlePermit2Deposit)}
                  loading={permit2Loading}
                  type="primary"
                >
                  Deposit with Permit2
                </Button>
             
                <Button
                  onClick={() => form.validateFields().then(handleWithdraw)}
                  loading={withdrawLoading}
                >
                  Withdraw
                </Button>
              </Space>
            </Form>
          </>
        )}
      </Card>
    </div>
  );
};

export default TokenBankWithERC20;
