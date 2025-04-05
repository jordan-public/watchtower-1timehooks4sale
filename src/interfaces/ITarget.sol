// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface ITarget {
    function callback(uint256 targetId) external;
}