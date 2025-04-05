// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./types/TWatch.sol";
import "./interfaces/ITarget.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

contract WatchList {
    uint256 private nextId = 1;
    uint256 public lastPrice;
    bool public directionDown;
    uint256 private lastRemovedPosition;
    uint256 private lastRemovedPrice;
    
    mapping(uint256 => TWatch) public watches;
    mapping(uint256 => uint256) public next;
    mapping(uint256 => uint256) public prev;
    uint256 public head;
    uint256 public tail;
    
    constructor(bool _directionDown, uint256 _initialPrice) {
        directionDown = _directionDown;
        lastPrice = _initialPrice;
        lastRemovedPrice = _initialPrice;
    }
    
    function insert(
        uint256 thresholdPrice,
        ITarget target,
        uint256 targetId,
        uint256 callerReward,
        uint256 poolReward,
        IERC20 poolRewardToken,
        uint256 tryInsertAfter
    ) external returns (uint256) {
        uint256 id = nextId++;
        
        TWatch memory watch = TWatch({
            id: id,
            direction: directionDown,
            thresholdPrice: thresholdPrice,
            target: target,
            targetId: targetId,
            callerReward: callerReward,
            poolReward: poolReward,
            poolRewardToken: poolRewardToken
        });
        
        watches[id] = watch;
        
        if (head == 0) {
            head = tail = id;
            return id;
        }

        // If a hint location is provided, verify and use it
        if (tryInsertAfter != 0) {
            require(watches[tryInsertAfter].id != 0, "Invalid hint location");
            require(next[tryInsertAfter] != 0, "Cannot insert after tail with hint");
            
            if (directionDown) {
                require(
                    watches[tryInsertAfter].thresholdPrice <= thresholdPrice && 
                    watches[next[tryInsertAfter]].thresholdPrice >= thresholdPrice,
                    "Incorrect hint location"
                );
            } else {
                require(
                    watches[tryInsertAfter].thresholdPrice >= thresholdPrice && 
                    watches[next[tryInsertAfter]].thresholdPrice <= thresholdPrice,
                    "Incorrect hint location"
                );
            }
            
            // Insert at the hinted position
            next[id] = next[tryInsertAfter];
            prev[id] = tryInsertAfter;
            prev[next[tryInsertAfter]] = id;
            next[tryInsertAfter] = id;
            return id;
        }
        
        // Default insertion logic when no hint is provided
        if ((directionDown && thresholdPrice >= watches[tail].thresholdPrice) ||
            (!directionDown && thresholdPrice <= watches[tail].thresholdPrice)) {
            prev[id] = tail;
            next[tail] = id;
            tail = id;
            return id;
        }
        
        if ((directionDown && thresholdPrice <= watches[head].thresholdPrice) ||
            (!directionDown && thresholdPrice >= watches[head].thresholdPrice)) {
            next[id] = head;
            prev[head] = id;
            head = id;
            return id;
        }
        
        uint256 current = head;
        while (current != 0) {
            if ((directionDown && thresholdPrice <= watches[next[current]].thresholdPrice) ||
                (!directionDown && thresholdPrice >= watches[next[current]].thresholdPrice)) {
                next[id] = next[current];
                prev[id] = current;
                prev[next[current]] = id;
                next[current] = id;
                return id;
            }
            current = next[current];
        }
        
        return id;
    }
    
    function remove(uint256 id) external {
        require(watches[id].id != 0, "Watch not found");
        
        if (head == tail) {
            head = tail = 0;
        } else if (id == head) {
            head = next[head];
            prev[head] = 0;
        } else if (id == tail) {
            tail = prev[tail];
            next[tail] = 0;
        } else {
            next[prev[id]] = next[id];
            prev[next[id]] = prev[id];
        }
        
        // Call the target callback - off for demo!!!
        //watches[id].target.callback(watches[id].targetId);
console.log("Calling target callback - liquidation");
        // Optionally transfer rewards - off for demo!!!
        // if (watches[id].callerReward > 0) {
        //     // Fix this!!! Pay the swap caller, nat the immediate caller
        //     payable(msg.sender).transfer(watches[id].callerReward);
        // }
        // if (watches[id].poolReward > 0) {
        //     // Fix this!!! Pay the pool, not the immediate caller
        //     watches[id].poolRewardToken.transfer(msg.sender, watches[id].poolReward);
        // }

        // Clean up the watch
        delete watches[id];
        delete next[id];
        delete prev[id];
    }
    
    function catchUp(uint256 newPrice) external {
        bool priceIncreased = newPrice > lastPrice;
        uint256 current;
        
        // If price moved in opposite direction of what we're watching, reset position
        if ((directionDown && priceIncreased) || (!directionDown && !priceIncreased)) {
            current = head;
            lastRemovedPosition = 0;
            lastRemovedPrice = newPrice;
        } else {
            // Continue from last position if moving in same direction
            current = (lastRemovedPosition != 0) ? lastRemovedPosition : head;
        }
        
        while (current != 0) {
            TWatch memory watch = watches[current];
            uint256 nextWatch = next[current];
            
            if ((directionDown && !priceIncreased && lastPrice >= watch.thresholdPrice && newPrice <= watch.thresholdPrice) ||
                (!directionDown && priceIncreased && lastPrice <= watch.thresholdPrice && newPrice >= watch.thresholdPrice)) {
                lastRemovedPosition = nextWatch;
                lastRemovedPrice = watch.thresholdPrice;
                this.remove(current); // This calls the target callback as well
            } else if ((directionDown && watch.thresholdPrice > newPrice) ||
                     (!directionDown && watch.thresholdPrice < newPrice)) {
                // We've gone past possible triggers, no need to continue
                break;
            }
            
            current = nextWatch;
        }
        
        lastPrice = newPrice;
    }
}