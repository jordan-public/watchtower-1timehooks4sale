// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {FullMath} from "v4-core/src/libraries/FullMath.sol";
import {console} from "forge-std/console.sol";

import "./WatchList.sol";
import "./interfaces/IWatchtower.sol";

contract Watchtower is BaseHook, IWatchtower {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public afterSwapCount; // For testing purposes only

    mapping(PoolId => WatchList) public upListByPool;
    mapping(PoolId => WatchList) public downListByPool;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        poolManager = _poolManager;
    }

    function registerWatcher(
        PoolKey calldata key,
        bool directionDown,
        uint256 thresholdPrice,
        ITarget target,
        uint256 targetId,
        uint256 callerReward,
        uint256 poolReward,
        IERC20 poolRewardToken,
        uint256 tryInsertAfter // 0 means no hint
    ) external {
        // Check if the price is above or below the current price
        PoolId poolId = key.toId();
        (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(poolId);
        uint256 currentPrice = FullMath.mulDiv(uint256(sqrtPriceX96) * uint256(sqrtPriceX96), 1e18, 1 << 192);
        
        if (directionDown) {
            WatchList watchList = downListByPool[poolId];
            if (WatchList(address(0)) == watchList) {
                watchList = new WatchList(directionDown, currentPrice);
                downListByPool[poolId] = watchList;
            }
            watchList.insert(thresholdPrice, target, targetId, callerReward, poolReward, poolRewardToken, tryInsertAfter);
        } else {
            WatchList watchList = upListByPool[poolId];
            if (WatchList(address(0)) == watchList) {
                watchList = new WatchList(directionDown, currentPrice);
                upListByPool[poolId] = watchList;
            }
            watchList.insert(thresholdPrice, target, targetId, callerReward, poolReward, poolRewardToken, tryInsertAfter);
        }
    }

    function removeWatcher(PoolKey calldata key, bool directionDown, uint256 id) external {
        PoolId poolId = key.toId();
        if (directionDown) {
            WatchList downList = downListByPool[poolId];
            require(WatchList(address(0)) != downList, "poolId not found in downList");
            downList.remove(id);
        } else {
            WatchList upList = upListByPool[poolId];
            require(WatchList(address(0)) != upList, "poolId not found in upList");
            upList.remove(id);
        }
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function _afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        // Discover the new price.
        PoolId poolId = key.toId();
        (uint160 sqrtNewPriceX96, , , ) = poolManager.getSlot0(poolId);
        uint256 newPrice = FullMath.mulDiv(uint256(sqrtNewPriceX96) * uint256(sqrtNewPriceX96), 1e18, 1 << 192);
        //console.log("New price: %s", newPrice);

        // Catch up on WatchList of callbacks in both directions
        WatchList downList = downListByPool[poolId];
        if (WatchList(address(0)) != downList) {
            downList.catchUp(newPrice);
        }
        WatchList upList = upListByPool[poolId];
        if (WatchList(address(0)) != upList) {
            upList.catchUp(newPrice);
        }

        afterSwapCount[key.toId()]++;
        return (BaseHook.afterSwap.selector, 0);
    }
}
