// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "../interfaces/ITarget.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

struct TWatch {
    uint256 id; // unique identifier for the watch
    bool direction; // true for falling, false for rising
    uint256 thresholdPrice; // in basis points
    ITarget target; // target contract to call
    uint256 targetId; // target ID for identification on the target contract
    uint256 callerReward; // in ETH
    uint256 poolReward; // in ERC20 tokens
    IERC20 poolRewardToken; // ERC20 token for pool reward
}
