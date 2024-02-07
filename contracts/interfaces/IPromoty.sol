// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPromoty {
    struct Reward {
        uint256 amount;
        uint256 expiresAt;
        uint256 creatorFid;
    }

    event ExpiredRewardClaimed(bytes messageHash, uint256 creatorFid, uint256 reward);
    event RewardClaimed(bytes messageHash, uint256 recasterFid, uint256 reward);
    event RecastRewarded(bytes messageHash, uint256 recasterFid, uint256 reward);

    error FailedToSendExpiredReward();
    error FailedToSendReward();
    error InvalidSignature();
    error InvalidEncoding();
    error InvalidMessageType();
    error InvalidValue();
    error InvalidReactionType();
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

    function rewardRecast(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid,
        uint64 duration
    ) external payable;
}
