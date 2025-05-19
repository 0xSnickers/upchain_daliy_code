// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract esRNT {
    struct LockInfo{
        address user; // 占 1 slot
        uint64 startTime;  // uint64，但占满 1 slot
        uint256 amount; // 占 1 slot
    }
    LockInfo[] private _locks; // base slot=0

    constructor() { 
        for (uint256 i = 0; i < 11; i++) {
            _locks.push(LockInfo(address(uint160(i+1)), uint64(block.timestamp*2-i), 1e18*(i+1)));
        }
    }
}
