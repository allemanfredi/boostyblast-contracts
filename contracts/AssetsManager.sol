// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IAssetsManager } from "./interfaces/IAssetsManager.sol";

contract AssetsManager is IAssetsManager {
    mapping(address => bool) private _enabledAssets;

    /// @inheritdoc IAssetsManager
    function disableAsset(address asset) external virtual {}

    /// @inheritdoc IAssetsManager
    function enableAsset(address asset) external virtual {}

    /// @inheritdoc IAssetsManager
    function isAssetEnabled(address asset) public view returns (bool) {
        return _enabledAssets[asset];
    }

    function _disableAsset(address asset) internal {
        _enabledAssets[asset] = false;
        emit AssetDisabled(asset);
    }

    function _enableAsset(address asset) internal {
        _enabledAssets[asset] = true;
        emit AssetEnabled(asset);
    }
}
