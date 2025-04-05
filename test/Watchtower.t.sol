// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Watchtower} from "../src/Watchtower.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {MockERC20} from "v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LoanPairFactory} from "../src/LoanPairFactory.sol";
import {ILoanPair} from "../src/interfaces/ILoanPair.sol";
import {ITarget} from "../src/interfaces/ITarget.sol";
import {LoanPair} from "../src/LoanPair.sol";

contract WatchtowerTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Watchtower hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    MockERC20 public loanToken;
    MockERC20 public collateralToken;
    LoanPairFactory public factory;
    ILoanPair public loanPair;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        (Currency currency0, Currency currency1) = deployMintAndApprove2Currencies();
        loanToken = MockERC20(Currency.unwrap(currency0));
        collateralToken = MockERC20(Currency.unwrap(currency1));

        alice = address(0x1);
        bob = address(0x2);
        loanToken.mint(alice, 1000e18);
        collateralToken.mint(alice, 1000e18);
        loanToken.mint(bob, 1000e18);
        collateralToken.mint(bob, 1000e18);

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("Watchtower.sol:Watchtower", constructorArgs, flags);
        hook = Watchtower(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        // Create a LendingPair
        factory = new LoanPairFactory();
        loanPair = factory.createLoanPair(IERC20(address(loanToken)), IERC20(address(collateralToken)));
        //LoanPair(address(loanPair)).setPoolKey(key);
        //LoanPair(address(loanPair)).setWatchtower(hook);
        //LoanPair(address(loanPair)).setExchangeRate(1e18); // Initial 1:1 exchange rate - mock oracle
        
        // Deposit to lending pair
        vm.startPrank(alice);
        loanToken.approve(address(loanPair), type(uint256).max);
        collateralToken.approve(address(loanPair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        loanToken.approve(address(loanPair), type(uint256).max);
        collateralToken.approve(address(loanPair), type(uint256).max);
        vm.stopPrank();
    }

    function testWatchtowerHooks() public {
        // Alice deposits into lending pool
        vm.startPrank(alice);
        loanPair.deposit(100e18);
        vm.stopPrank();

        // Bob borrows
        vm.startPrank(bob);
        loanPair.borrow(50e18);
        vm.stopPrank();

        uint256 targetId = LoanPair(address(loanPair)).setTargetId2Borrower(bob);

        hook.registerWatcher(
            key,
            true, // directionDown
            1e20, // thresholdPrice
            ITarget(address(loanPair)), // target
            targetId,
            0, // callerReward
            0, // poolReward
            IERC20(address(collateralToken)), // poolRewardToken
            0 // tryInsertAfter
        );

        LoanPair(address(loanPair)).setMockExchangeRate(5e17); // 0.5, collateral worth less - mock oracle
        
        // positions were created in setup()
        assertEq(hook.afterSwapCount(poolId), 0);

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e18; // negative number indicates exact input swap!
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        assertEq(int256(swapDelta.amount0()), amountSpecified);

        assertEq(hook.afterSwapCount(poolId), 1);
    }
}
