// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRecastPromoter {
    struct Reward {
        uint256 amount;
        uint256 expiresAt;
        uint256 expiredReceiverFid;
        address asset;
    }

    event AssetDisabled(address indexed asset);
    event AssetEnabled(address indexed asset);
    event ExpiredRewardClaimed(
        bytes20 indexed messageHash,
        uint256 indexed expiredReceiverFid,
        address asset,
        uint256 amount
    );
    event IdRegistrySet(address idRegistry);
    event RewardClaimed(
        bytes20 indexed messageHash,
        bytes20 indexed recastedMessageHash,
        uint256 indexed recasterFid,
        address asset,
        uint256 amount
    );
    event RecastRewarded(
        bytes20 indexed messageHash,
        uint256 indexed creatorFid,
        uint256 indexed recasterFid,
        address asset,
        uint256 amount,
        uint256 duration
    );

    error AssetNotEnabled(address asset);
    error InvalidSignature();
    error InvalidEncoding();
    error InvalidFid();
    error InvalidMessageType();
    error InvalidAmount();
    error NoReward();
    error RewardExpired();
    error RewardNotExpired();

    function claimExpiredReward(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid
    ) external;

    function claimReward(bytes32 publicKey, bytes32 r, bytes32 s, bytes memory message) external;

    function disableAsset(address asset) external;

    function enableAsset(address asset) external;

    function getReward(bytes20 messageHash, uint256 recasterFid) external view returns (Reward memory);

    function isAssetEnabled(address asset) external view returns (bool);

    function rewardRecast(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid,
        uint256 expiredReceiverFid,
        address asset,
        uint256 amount,
        uint64 duration
    ) external payable;

    function setIdRegistry(address idRegistry_) external;

    function withdrawAsset(address asset, address receiver, uint256 amount) external;
}
