// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {ITarget} from "./ITarget.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IWatchtower {
    function registerWatcher(
        PoolKey calldata key,
        bool directionDown,
        uint256 thresholdPrice,
        ITarget target,
        uint256 targetId,
        uint256 callerReward,
        uint256 poolReward,
        IERC20 poolRewardToken,
        uint256 tryInsertAfter
    ) external;

    function removeWatcher(
        PoolKey calldata key,
        bool directionDown,
        uint256 id
    ) external;
}