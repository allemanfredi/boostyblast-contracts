// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MessageDataCodec, MessageData, MessageType, ReactionType, CastId } from "farcaster-solidity/contracts/protobufs/message.proto.sol";
import { Blake3 } from "farcaster-solidity/contracts/libraries/Blake3.sol";
import { Ed25519 } from "farcaster-solidity/contracts/libraries/Ed25519.sol";
import { IPromoty } from "./interfaces/IPromoty.sol";
import { IIdRegistry } from "./interfaces/IIdRegistry.sol";

contract Promoty is IPromoty {
    address public immutable ID_REGISTRY;

    mapping(bytes => mapping(uint256 => Reward)) private _rewards;

    constructor(address idRegistry) {
        ID_REGISTRY = idRegistry;
    }

    /// @inheritdoc IPromoty
    function claimExpiredReward(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid
    ) external {
        (, bytes memory messageHash) = _verifyMessage(publicKey, r, s, message);

        Reward storage reward = _rewards[messageHash][recasterFid];
        uint256 creatorFid = reward.creatorFid;
        if (creatorFid == 0) revert NoReward();
        uint256 rewardAmount = reward.amount;
        address rewardCreator = IIdRegistry(ID_REGISTRY).custodyOf(reward.creatorFid);
        if (rewardCreator == address(0)) revert InvalidFid();
        if (block.timestamp <= reward.expiresAt) revert RewardNotExpired();
        delete _rewards[messageHash][recasterFid];

        (bool sent, ) = rewardCreator.call{ value: rewardAmount }("");
        if (!sent) revert FailedToSendExpiredReward();
        emit ExpiredRewardClaimed(messageHash, creatorFid, rewardAmount);
    }

    /// @inheritdoc IPromoty
    function claimReward(bytes32 publicKey, bytes32 r, bytes32 s, bytes memory message) external {
        (MessageData memory messageData, bytes memory messageHash) = _verifyMessage(publicKey, r, s, message);
        if (messageData.type_ != MessageType.MESSAGE_TYPE_REACTION_ADD) revert InvalidMessageType();
        if (messageData.reaction_body.type_ != ReactionType.REACTION_TYPE_RECAST) revert InvalidReactionType();

        bytes memory recastedMessageHash = messageData.reaction_body.target_cast_id.hash_;
        uint256 recastedMessageFid = messageData.fid;
        Reward storage reward = _rewards[recastedMessageHash][recastedMessageFid];
        uint256 rewardAmount = reward.amount;
        if (rewardAmount == 0) revert NoReward();
        // NOTE: using message.timestamp could allow an "attacker" to sign the message and don't broadcasting for a long time
        if (block.timestamp > reward.expiresAt) revert RewardExpired();
        delete _rewards[recastedMessageHash][recastedMessageFid];

        // TODO: send percentage to Promoty
        address recaster = IIdRegistry(ID_REGISTRY).custodyOf(recastedMessageFid);
        if (recaster == address(0)) revert InvalidFid();
        (bool sent, ) = recaster.call{ value: rewardAmount }("");
        if (!sent) revert FailedToSendReward();
        emit RewardClaimed(messageHash, recastedMessageFid, rewardAmount);
    }

    /// @inheritdoc IPromoty
    function rewardRecast(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid,
        uint64 duration
    ) external payable {
        if (msg.value == 0) revert InvalidValue();
        (MessageData memory messageData, bytes memory messageHash) = _verifyMessage(publicKey, r, s, message);
        if (messageData.type_ != MessageType.MESSAGE_TYPE_CAST_ADD) revert InvalidMessageType();
        uint256 currentRewardValue = _rewards[messageHash][recasterFid].amount;
        _rewards[messageHash][recasterFid] = Reward(
            currentRewardValue + msg.value,
            block.timestamp + duration,
            messageData.fid
        );
        emit RecastRewarded(messageHash, recasterFid, msg.value);
    }

    function _verifyMessage(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message
    ) internal pure returns (MessageData memory, bytes memory) {
        bytes memory messageHash = Blake3.hash(message, 20);
        bool valid = Ed25519.verify(publicKey, r, s, messageHash);
        if (!valid) revert InvalidSignature();
        (bool success, , MessageData memory messageData) = MessageDataCodec.decode(0, message, uint64(message.length));
        if (!success) revert InvalidEncoding();
        return (messageData, messageHash);
    }
}
