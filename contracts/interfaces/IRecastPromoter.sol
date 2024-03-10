// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRecastPromoter {
    struct Reward {
        uint256 amount;
        uint256 expiresAt;
        uint256 expiredReceiverFid;
        address asset;
    }

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
    event Promoted(
        bytes20 indexed messageHash,
        uint256 indexed creatorFid,
        uint256 indexed recasterFid,
        address asset,
        uint256 amount,
        uint256 expiresAt
    );

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

    function getReward(bytes20 messageHash, uint256 recasterFid) external view returns (Reward memory);

    function rewardRecastOrQuote(
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

    function withdrawAccruedFeesByAsset(address asset, address receiver) external;
}
