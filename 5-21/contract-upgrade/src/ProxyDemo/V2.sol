// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./V1.sol";

contract V2 is V1 {
    string public newFeature;

    function initializeV2(string memory _newFeature) public reinitializer(2) {
        newFeature = _newFeature;
        version = "v2";
    }

    function getNewFeature() external view returns (string memory) {
        return newFeature;
    }
}
