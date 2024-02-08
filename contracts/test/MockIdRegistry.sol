// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockIdRegistry {
    mapping(uint256 => address) public owners;

    function setAddressForFid(uint256 fid, address owner) external {
        owners[fid] = owner;
    }

    function custodyOf(uint256 fid) external view returns (address) {
        return owners[fid];
    }
}
