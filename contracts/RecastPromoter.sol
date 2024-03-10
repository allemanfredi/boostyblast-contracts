// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageDataCodec, MessageData, MessageType, ReactionType } from "farcaster-solidity/contracts/protobufs/message.proto.sol";
import { Blake3 } from "farcaster-solidity/contracts/libraries/Blake3.sol";
import { Ed25519 } from "farcaster-solidity/contracts/libraries/Ed25519.sol";
import { IRecastPromoter } from "./interfaces/IRecastPromoter.sol";
import { IIdRegistry } from "./interfaces/IIdRegistry.sol";
import { AssetsManager } from "./AssetsManager.sol";

contract RecastPromoter is IRecastPromoter, Ownable, AssetsManager {
    uint256 public constant FEE_PERCENTAGE = 50; // 0.5%
    uint256 public constant PERCENTAGE_DIVISOR = 10000;

    address public idRegistry;

    mapping(bytes20 => mapping(uint256 => Reward)) private _rewards;
    mapping(address => uint256) private _accruedFees;

    constructor(address idRegistry_) Ownable(msg.sender) AssetsManager() {
        idRegistry = idRegistry_;
    }

    /// @inheritdoc IRecastPromoter
    function claimExpiredReward(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message,
        uint256 recasterFid
    ) external {
        (, bytes20 messageHash) = _verifyMessage(publicKey, r, s, message);

        Reward storage reward = _rewards[messageHash][recasterFid];
        uint256 expiredReceiverFid = reward.expiredReceiverFid;
        if (expiredReceiverFid == 0) revert NoReward();
        uint256 rewardAmount = reward.amount;
        address rewardAsset = reward.asset;
        address rewardCreator = IIdRegistry(idRegistry).custodyOf(reward.expiredReceiverFid);
        if (rewardCreator == address(0)) revert InvalidFid();
        if (block.timestamp <= reward.expiresAt) revert RewardNotExpired();
        delete _rewards[messageHash][recasterFid];
        IERC20(rewardAsset).transfer(rewardCreator, rewardAmount);
        emit ExpiredRewardClaimed(messageHash, expiredReceiverFid, rewardAsset, rewardAmount);
    }

    /// @inheritdoc IRecastPromoter
    function claimReward(bytes32 publicKey, bytes32 r, bytes32 s, bytes memory message) external {
        (MessageData memory messageData, bytes20 messageHash) = _verifyMessage(publicKey, r, s, message);

        bytes20 recastedMessageHash;
        uint256 recasterFid = messageData.fid;

        if (
            messageData.type_ == MessageType.MESSAGE_TYPE_REACTION_ADD &&
            messageData.reaction_body.type_ == ReactionType.REACTION_TYPE_RECAST
        ) {
            recastedMessageHash = bytes20(messageData.reaction_body.target_cast_id.hash_);
        } else if (
            messageData.type_ == MessageType.MESSAGE_TYPE_CAST_ADD && messageData.cast_add_body.embeds.length > 0
        ) {
            recastedMessageHash = bytes20(messageData.cast_add_body.embeds[0].cast_id.hash_);
        } else {
            revert NoReward();
        }

        Reward storage reward = _rewards[recastedMessageHash][recasterFid];
        uint256 rewardAmount = reward.amount;
        address rewardAsset = reward.asset;
        if (rewardAmount == 0) revert NoReward();
        if (block.timestamp > reward.expiresAt) revert RewardExpired();
        delete _rewards[recastedMessageHash][recasterFid];

        uint256 fee = (rewardAmount * FEE_PERCENTAGE) / PERCENTAGE_DIVISOR;
        uint256 recasterRewardAmount = rewardAmount - fee;
        _accruedFees[rewardAsset] += fee;

        address recaster = IIdRegistry(idRegistry).custodyOf(recasterFid);
        if (recaster == address(0)) revert InvalidFid();

        IERC20(rewardAsset).transfer(recaster, recasterRewardAmount);
        emit RewardClaimed(messageHash, recastedMessageHash, recasterFid, rewardAsset, recasterRewardAmount);
    }

    function disableAsset(address asset) external override onlyOwner {
        _disableAsset(asset);
    }

    function enableAsset(address asset) external override onlyOwner {
        _enableAsset(asset);
    }

    /// @inheritdoc IRecastPromoter
    function getReward(bytes20 messageHash, uint256 recasterFid) external view returns (Reward memory) {
        return _rewards[messageHash][recasterFid];
    }

    /// @inheritdoc IRecastPromoter
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
    ) external payable {
        if (!isAssetEnabled(asset)) revert AssetNotEnabled(asset);
        if (amount == 0) revert InvalidAmount();
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        (MessageData memory messageData, bytes20 messageHash) = _verifyMessage(publicKey, r, s, message);
        if (messageData.type_ != MessageType.MESSAGE_TYPE_CAST_ADD) revert InvalidMessageType();
        uint256 currentRewardValue = _rewards[messageHash][recasterFid].amount;
        uint256 expiresAt = block.timestamp + duration;
        _rewards[messageHash][recasterFid] = Reward(currentRewardValue + amount, expiresAt, expiredReceiverFid, asset);
        emit Promoted(messageHash, messageData.fid, recasterFid, asset, amount, expiresAt);
    }

    /// @inheritdoc IRecastPromoter
    function setIdRegistry(address idRegistry_) external onlyOwner {
        idRegistry = idRegistry_;
        emit IdRegistrySet(idRegistry_);
    }

    /// @inheritdoc IRecastPromoter
    function withdrawAccruedFeesByAsset(address asset, address receiver) external onlyOwner {
        IERC20(asset).transfer(receiver, _accruedFees[asset]);
        _accruedFees[asset] = 0;
    }

    function _verifyMessage(
        bytes32 publicKey,
        bytes32 r,
        bytes32 s,
        bytes memory message
    ) internal pure returns (MessageData memory, bytes20) {
        bytes memory messageHash = Blake3.hash(message, 20);
        bool valid = Ed25519.verify(publicKey, r, s, messageHash);
        if (!valid) revert InvalidSignature();
        (bool success, , MessageData memory messageData) = MessageDataCodec.decode(0, message, uint64(message.length));
        if (!success) revert InvalidEncoding();
        return (messageData, bytes20(messageHash));
    }
}
