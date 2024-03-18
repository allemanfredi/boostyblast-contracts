// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IReferenceModule } from "@lens-protocol/core/contracts/interfaces/IReferenceModule.sol";
import { HubRestricted } from "@lens-protocol/core/contracts/base/HubRestricted.sol";
import { Types } from "@lens-protocol/core/contracts/libraries/constants/Types.sol";
import { LensModuleMetadata } from "@lens-protocol/core/contracts/modules/LensModuleMetadata.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IPromoteReferenceModule } from "./interfaces/IPromoteReferenceModule.sol";
import { AssetsManager } from "./AssetsManager.sol";

contract PromoteReferenceModule is
    IReferenceModule,
    IPromoteReferenceModule,
    LensModuleMetadata,
    HubRestricted,
    AssetsManager
{
    uint256 public constant FEE_PERCENTAGE = 50; // 0.5%
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    mapping(uint256 => mapping(uint256 => Reward)) private _rewards;
    mapping(address => uint256) private _accruedFees;

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == type(IReferenceModule).interfaceId || super.supportsInterface(interfaceID);
    }

    constructor(address hub, address moduleOwner) HubRestricted(hub) LensModuleMetadata(moduleOwner) AssetsManager() {}

    function claimExpiredReward(uint256 pubId, uint256 collectorProfileId) external {
        Reward storage reward = _rewards[pubId][collectorProfileId];
        uint256 rewardAmount = reward.amount;
        if (rewardAmount == 0) revert RewardNotFound();
        if (block.timestamp < reward.expiresAt) revert RewardNotExpired();
        uint256 creatorProfileId = reward.creatorProfileId;
        address creator = IERC721(HUB).ownerOf(creatorProfileId);
        IERC20(reward.asset).transfer(creator, rewardAmount);
        emit ExpiredRewardClaimed(
            pubId,
            creatorProfileId,
            collectorProfileId,
            reward.asset,
            reward.amount,
            reward.expiresAt
        );
        delete _rewards[pubId][collectorProfileId];
    }

    function disableAsset(address asset) external override onlyOwner {
        _disableAsset(asset);
    }

    function enableAsset(address asset) external override onlyOwner {
        _enableAsset(asset);
    }

    /// @inheritdoc IPromoteReferenceModule
    function getAccruedFeesByAsset(address asset) external view returns (uint256) {
        return _accruedFees[asset];
    }

    /// @inheritdoc IPromoteReferenceModule
    function getRewardByPubIdOf(uint256 pubId, uint256 collectorProfileId) external view returns (Reward memory) {
        return _rewards[pubId][collectorProfileId];
    }

    /// @inheritdoc IReferenceModule
    function initializeReferenceModule(
        uint256 creatorProfileId,
        uint256 pubId,
        address /* transactionExecutor */,
        bytes calldata data
    ) external onlyHub returns (bytes memory) {
        address creator = IERC721(HUB).ownerOf(creatorProfileId);

        (
            address[] memory assets,
            uint256[] memory amounts,
            uint256[] memory collectorProfileIds,
            uint64[] memory durations
        ) = abi.decode(data, (address[], uint256[], uint256[], uint64[]));

        for (uint256 i = 0; i < collectorProfileIds.length; ) {
            address asset = assets[i];

            if (amounts[i] == 0) revert AmountCannotBeZero();
            if (!isAssetEnabled(asset)) revert AssetNotEnabled(asset);

            for (uint256 j = 0; j < collectorProfileIds.length; ) {
                if (i != j && collectorProfileIds[i] == collectorProfileIds[j])
                    revert CannotAssignDoubleRewardToTheSameProfile(collectorProfileIds[j]);
                unchecked {
                    ++j;
                }
            }

            IERC20(asset).transferFrom(creator, address(this), amounts[i]);

            uint256 expiresAt = block.timestamp + durations[i];
            _rewards[pubId][collectorProfileIds[i]] = Reward(asset, creatorProfileId, amounts[i], expiresAt);
            emit Promoted(pubId, creatorProfileId, collectorProfileIds[i], asset, amounts[i], expiresAt);

            unchecked {
                ++i;
            }
        }

        return "";
    }

    /// @inheritdoc IReferenceModule
    function processComment(
        Types.ProcessCommentParams calldata //processCommentParams
    ) external view override onlyHub returns (bytes memory) {
        return "";
    }

    /// @inheritdoc IReferenceModule
    function processQuote(
        Types.ProcessQuoteParams calldata processQuoteParams
    ) external override onlyHub returns (bytes memory) {
        return
            _processMirrorOrQuote(
                processQuoteParams.pointedPubId,
                processQuoteParams.profileId,
                processQuoteParams.pointedProfileId
            );
    }

    /// @inheritdoc IReferenceModule
    function processMirror(
        Types.ProcessMirrorParams calldata processMirrorParams
    ) external override onlyHub returns (bytes memory) {
        return
            _processMirrorOrQuote(
                processMirrorParams.pointedPubId,
                processMirrorParams.profileId,
                processMirrorParams.pointedProfileId
            );
    }

    /// @inheritdoc IPromoteReferenceModule
    function withdrawAccruedFeesByAsset(address asset, address receiver) external onlyOwner {
        IERC20(asset).transfer(receiver, _accruedFees[asset]);
        _accruedFees[asset] = 0;
    }

    function _processMirrorOrQuote(
        uint256 pointedPubId,
        uint256 collectorProfileId,
        uint256 creatorProfileId
    ) internal returns (bytes memory) {
        Reward storage reward = _rewards[collectorProfileId][pointedPubId];

        uint256 expiresAt = reward.expiresAt;
        if (block.timestamp < expiresAt) {
            address rewardAsset = reward.asset;
            uint256 rewardAmount = reward.amount;

            uint256 fee = (rewardAmount * FEE_PERCENTAGE) / PERCENTAGE_DIVISOR;
            uint256 collectorRewardAmount = rewardAmount - fee;
            _accruedFees[rewardAsset] += fee;

            delete _rewards[collectorProfileId][pointedPubId];
            IERC20(rewardAsset).transfer(IERC721(HUB).ownerOf(collectorProfileId), collectorRewardAmount);
            emit RewardCollected(
                pointedPubId,
                creatorProfileId,
                collectorProfileId,
                rewardAsset,
                collectorRewardAmount,
                expiresAt
            );
        }

        return "";
    }
}
