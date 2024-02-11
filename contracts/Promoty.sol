// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MessageDataCodec, MessageData, MessageType, ReactionType } from "farcaster-solidity/contracts/protobufs/message.proto.sol";
import { Blake3 } from "farcaster-solidity/contracts/libraries/Blake3.sol";
import { Ed25519 } from "farcaster-solidity/contracts/libraries/Ed25519.sol";
import { IPromoty } from "./interfaces/IPromoty.sol";
import { IIdRegistry } from "./interfaces/IIdRegistry.sol";

contract Promoty is IPromoty, Ownable {
    uint256 public constant FEE = 50; // 0.5%
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    address public idRegistry;

    mapping(bytes => mapping(uint256 => Reward)) private _rewards;

    constructor(address idRegistry_) Ownable(msg.sender) {
        idRegistry = idRegistry_;
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
        uint256 expiredReceiverFid = reward.expiredReceiverFid;
        if (expiredReceiverFid == 0) revert NoReward();
        uint256 rewardAmount = reward.amount;
        address rewardCreator = IIdRegistry(idRegistry).custodyOf(reward.expiredReceiverFid);
        if (rewardCreator == address(0)) revert InvalidFid();
        if (block.timestamp <= reward.expiresAt) revert RewardNotExpired();
        delete _rewards[messageHash][recasterFid];

        (bool sent, ) = rewardCreator.call{ value: rewardAmount }("");
        if (!sent) revert FailedToSendExpiredReward();
        emit ExpiredRewardClaimed(messageHash, expiredReceiverFid, rewardAmount);
    }

    /// @inheritdoc IPromoty
    function claimReward(bytes32 publicKey, bytes32 r, bytes32 s, bytes memory message) external {
        (MessageData memory messageData, bytes memory messageHash) = _verifyMessage(publicKey, r, s, message);

        bytes memory recastedMessageHash;
        uint256 recasterFid = messageData.fid;

        if (
            messageData.type_ == MessageType.MESSAGE_TYPE_REACTION_ADD &&
            messageData.reaction_body.type_ == ReactionType.REACTION_TYPE_RECAST
        ) {
            recastedMessageHash = messageData.reaction_body.target_cast_id.hash_;
        } else if (
            messageData.type_ == MessageType.MESSAGE_TYPE_CAST_ADD && messageData.cast_add_body.embeds.length > 0
        ) {
            recastedMessageHash = messageData.cast_add_body.embeds[0].cast_id.hash_;
        } else {
            revert NoReward();
        }

        Reward storage reward = _rewards[recastedMessageHash][recasterFid];
        uint256 rewardAmount = reward.amount;
        if (rewardAmount == 0) revert NoReward();
        if (block.timestamp > reward.expiresAt) revert RewardExpired();
        delete _rewards[recastedMessageHash][recasterFid];

        uint256 fee = (rewardAmount * FEE) / PERCENTAGE_DIVISOR;
        uint256 recasterRewardAmount = rewardAmount - fee;

        address recaster = IIdRegistry(idRegistry).custodyOf(recasterFid);
        if (recaster == address(0)) revert InvalidFid();

        (bool sent, ) = recaster.call{ value: recasterRewardAmount }("");
        if (!sent) revert FailedToSendReward();
        emit RewardClaimed(messageHash, recasterFid, recasterRewardAmount);
    }

    /// @inheritdoc IPromoty
    function rewardRecast(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid,
        uint256 expiredReceiverFid,
        uint64 duration
    ) external payable {
        if (msg.value == 0) revert InvalidValue();
        (MessageData memory messageData, bytes memory messageHash) = _verifyMessage(publicKey, r, s, message);
        if (messageData.type_ != MessageType.MESSAGE_TYPE_CAST_ADD) revert InvalidMessageType();
        uint256 currentRewardValue = _rewards[messageHash][recasterFid].amount;
        _rewards[messageHash][recasterFid] = Reward(
            currentRewardValue + msg.value,
            block.timestamp + duration,
            expiredReceiverFid
        );
        emit RecastRewarded(messageHash, messageData.fid, recasterFid, msg.value);
    }

    /// @inheritdoc IPromoty
    function setIdRegistry(address idRegistry_) external onlyOwner {
        idRegistry = idRegistry_;
        emit IdRegistrySet(idRegistry_);
    }

    /// @inheritdoc IPromoty
    function withdrawAll(address receiver) external onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        (bool sent, ) = receiver.call{ value: amount }("");
        if (!sent) revert FailedToWithdraw();
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
