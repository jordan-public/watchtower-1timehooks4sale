// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/WatchList.sol";
import "../src/interfaces/ITarget.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract MockTarget is ITarget {
    bool public called;
    
    function callback(uint256) external {
        called = true;
    }
    
    function reset() external {
        called = false;
    }
}

contract WatchListTest is Test {
    WatchList watchList;
    MockTarget target;
    IERC20 mockToken;
    
    function setUp() public {
        watchList = new WatchList(true, 10000); // directionDown: true (falling), initial price: 10000
        target = new MockTarget();
        mockToken = IERC20(address(1)); // mock token address
    }
    
    function test_InsertWithoutHint() public {
        // Insert three watches in non-sequential order
        // For falling prices (directionDown=true), lower prices should come first
        uint256 id1 = watchList.insert(9000, ITarget(target), 0, 0, 0, mockToken, 0);
        uint256 id2 = watchList.insert(8000, ITarget(target), 0, 0, 0, mockToken, 0);
        uint256 id3 = watchList.insert(8500, ITarget(target), 0, 0, 0, mockToken, 0);
        
        // Verify order (should be 8000 -> 8500 -> 9000 for falling prices)
        assertEq(watchList.head(), id2);
        assertEq(watchList.next(id2), id3);
        assertEq(watchList.next(id3), id1);
        assertEq(watchList.tail(), id1);
    }
    
    function test_InsertWithHint() public {
        uint256 id1 = watchList.insert(9000, ITarget(target), 0, 0, 0, mockToken, 0);
        uint256 id2 = watchList.insert(8000, ITarget(target), 0, 0, 0, mockToken, 0);
        
        // Insert 8500 with hint after 8000
        uint256 id3 = watchList.insert(8500, ITarget(target), 0, 0, 0, mockToken, id2);
        
        // Verify order (8000 -> 8500 -> 9000)
        assertEq(watchList.next(id2), id3);
        assertEq(watchList.next(id3), id1);
    }
    
    function test_InsertWithIncorrectHint() public {
        uint256 id1 = watchList.insert(8000, ITarget(target), 0, 0, 0, mockToken, 0);
        uint256 id2 = watchList.insert(9000, ITarget(target), 0, 0, 0, mockToken, 0);
        
        // Try to insert 8500 with incorrect hint (after 9000)
        vm.expectRevert("Cannot insert after tail with hint");
        watchList.insert(8500, ITarget(target), 0, 0, 0, mockToken, id2);
    }
    
    function test_CatchUpSingleTrigger() public {
        watchList.insert(9000, ITarget(target), 0, 0, 0, mockToken, 0);
        
        // Price moves down past threshold
        watchList.catchUp(8500);
        assertTrue(target.called());
    }
    
    function test_CatchUpMultipleTriggers() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();
        
        watchList.insert(9000, ITarget(target1), 0, 0, 0, mockToken, 0);
        watchList.insert(8500, ITarget(target2), 0, 0, 0, mockToken, 0);
        
        // Price moves down past both thresholds
        watchList.catchUp(8000);
        assertTrue(target1.called());
        assertTrue(target2.called());
    }
    
    function test_CatchUpOptimizedSearch() public {
        uint256[] memory ids = new uint256[](5);
        MockTarget[] memory targets = new MockTarget[](5);
        
        // Create watches at 9000, 8000, 7000, 6000, 5000
        for(uint i = 0; i < 5; i++) {
            targets[i] = new MockTarget();
            ids[i] = watchList.insert(9000 - (i * 1000), ITarget(targets[i]), 0, 0, 0, mockToken, 0);
        }
        
        // First catchUp triggers first watch
        watchList.catchUp(8500);
        assertTrue(targets[0].called());
        assertFalse(targets[1].called());
        
        // Second catchUp should start from last position
        watchList.catchUp(7500);
        assertTrue(targets[1].called());
        assertFalse(targets[2].called());
    }
    
    function test_CatchUpDirectionChange() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();
        
        watchList.insert(9000, ITarget(target1), 0, 0, 0, mockToken, 0);
        watchList.insert(8000, ITarget(target2), 0, 0, 0, mockToken, 0);
        
        // Price moves down, then up, then down again
        watchList.catchUp(8500);
        assertTrue(target1.called());
        assertFalse(target2.called());
        
        target1.reset();
        watchList.catchUp(9500); // Price goes up, no triggers
        assertFalse(target1.called());
        assertFalse(target2.called());
        
        watchList.catchUp(7500); // Price goes down, triggers second watch
        assertFalse(target1.called());
        assertTrue(target2.called());
    }
}