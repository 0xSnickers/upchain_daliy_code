import { useAccount } from 'wagmi';
import { useMultiReadContracts } from './useMultiReadContracts';
import { MY_TOKEN_ABI, TOKEN_BANK_ABI } from '@/config';
import { Abi, Address } from 'viem';
/**
 * 获取最新余额
 */
interface TokenBankBalancesOptions {
  selectedToken: { 
    symbol: string;
    address: string;
  };
  tokenAddress: Address;
  tokenBankAddress: Address;
  enabled?: boolean;
  watch?: boolean;
  chainId: number;
}

type ContractRead = {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: readonly unknown[];
  chainId?: number;
};

type ContractReadResult = {
  result: bigint;
  status: 'success' | 'failure';
  error?: Error;
};

export const useTokenBankBalances = ({
  selectedToken,
  tokenAddress,
  tokenBankAddress,
  enabled = true,
  watch = false,
  chainId,
}: TokenBankBalancesOptions) => {
  const { address } = useAccount();

  const isETH = selectedToken.symbol === 'ETH';

  // 构建合约读取配置
  const contracts: ContractRead[] = [
    // 用户 token balance（非 ETH 才查）
    ...(isETH
      ? []
      : [
          {
            address: tokenAddress,
            abi: MY_TOKEN_ABI as Abi,
            functionName: 'balanceOf',
            args: [address!],
            chainId,
          },
        ]),
    // 合约中用户余额
    {
      address: tokenBankAddress,
      abi: TOKEN_BANK_ABI as Abi,
      functionName: isETH ? 'ethBalanceOf' : 'tokenBalanceOf',
      args: isETH ? [address!] : [tokenAddress, address!],
      chainId,
    },
    // 总存款
    {
      address: tokenBankAddress,
      abi: TOKEN_BANK_ABI as Abi,
      functionName: isETH ? 'totalEthDeposits' : 'getTotalTokenDeposits',
      args: isETH ? [] : [tokenAddress],
      chainId,
    },
  ];

  const { data, isLoading, refetch } = useMultiReadContracts({
    contracts,
    enabled: enabled && !!address,
    watch: watch,
    staleTime: 5000,
  });

  // 将 data 转换为正确的类型
  const typedData = (data || []) as ContractReadResult[];

  // 根据是否是 ETH 来解构数据
  const [tokenBal, bankBal, totalDeposits] = isETH
    ? [undefined, typedData[0]?.result, typedData[1]?.result]
    : [typedData[0]?.result, typedData[1]?.result, typedData[2]?.result];

  return {
    tokenBal,
    bankBal,
    totalDeposits,
    loading: isLoading,
    refetch,
  };
};
