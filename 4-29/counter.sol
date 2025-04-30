// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract Counter{
    int public counter = 0;

    function add(int x) external{
        counter = counter + x;
    }
    function get() external view returns(int new_counter){
        new_counter = counter;
    }
}
