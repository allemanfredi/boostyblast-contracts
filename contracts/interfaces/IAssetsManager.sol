// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAssetsManager {
    event AssetDisabled(address indexed asset);
    event AssetEnabled(address indexed asset);

    error AssetNotEnabled(address asset);

    function disableAsset(address asset) external;

    function enableAsset(address asset) external;

    function isAssetEnabled(address asset) external view returns (bool);
}
