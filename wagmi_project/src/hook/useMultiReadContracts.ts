import { useQuery } from "@tanstack/react-query";
import { readContracts } from "@wagmi/core";
import { config } from "@/config"; // wagmi config
import type { ReadContractsParameters } from "wagmi/actions";

interface MultiReadOptions extends Omit<ReadContractsParameters, "contracts"> {
  contracts: ReadContractsParameters["contracts"];
  enabled?: boolean;
  watch?: boolean;
  staleTime?: number;
}

/**
 * 高性能批量读取合约数据 Hook
 */
export function useMultiReadContracts({
  contracts,
  enabled = true,
  watch = false,
  staleTime = 5000,
  ...rest
}: MultiReadOptions) {
  return useQuery({
    queryKey: ["multiReadContracts", contracts],
    queryFn: async () => {
      const results = await readContracts(config,{
        contracts,
        ...rest,
      });
      return results;
    },
    enabled,
    staleTime,
    refetchInterval: watch ? 4000 : false,
  });
}
