import { ethers } from "hardhat";

async function main() {
  // 获取 UniswapV2Pair 合约工厂
  const UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair");
  
  // 获取合约的 bytecode
  const bytecode = UniswapV2Pair.bytecode;
  
  // 计算 keccak256 hash
  const initCodeHash = ethers.keccak256(bytecode);
  
  console.log("UniswapV2Pair bytecode:", bytecode);
  console.log("Init code hash:", initCodeHash);
  console.log("Init code hash (without 0x):", initCodeHash.slice(2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 