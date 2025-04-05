// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LoanPairFactory} from "../src/LoanPairFactory.sol";
import {ILoanPair} from "../src/interfaces/ILoanPair.sol";
import {LoanPair} from "../src/LoanPair.sol";

contract LoanTest is Test {
    MockERC20 public loanToken;
    MockERC20 public collateralToken;
    LoanPairFactory public factory;
    ILoanPair public loanPair;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        // Deploy tokens
        loanToken = new MockERC20("Loan Token", "LOAN", 18);
        collateralToken = new MockERC20("Collateral Token", "COLL", 18);
        
        // Deploy factory and create loan pair
        factory = new LoanPairFactory();
        loanPair = factory.createLoanPair(IERC20(address(loanToken)), IERC20(address(collateralToken)));

        // Setup initial balances using deal
        deal(address(loanToken), alice, 1000e18);
        deal(address(collateralToken), alice, 1000e18);
        deal(address(loanToken), bob, 1000e18);
        deal(address(collateralToken), bob, 1000e18);

        vm.startPrank(alice);
        loanToken.approve(address(loanPair), type(uint256).max);
        collateralToken.approve(address(loanPair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        loanToken.approve(address(loanPair), type(uint256).max);
        collateralToken.approve(address(loanPair), type(uint256).max);
        vm.stopPrank();
    }

    function test_BorrowAndRepay() public {
        // Alice deposits into lending pool
        vm.startPrank(alice);
        uint256 aliceShares = loanPair.deposit(100e18);
        assertEq(loanPair.shares(alice), aliceShares, "Shares not credited");
        vm.stopPrank();
        
        uint256 bobInitialLoanBalance = loanToken.balanceOf(bob);
        uint256 bobInitialCollBalance = collateralToken.balanceOf(bob);
        
        // Bob borrows
        vm.startPrank(bob);
        loanPair.borrow(50e18);
        
        assertEq(loanToken.balanceOf(bob), bobInitialLoanBalance + 50e18, "Loan amount not received");
        assertTrue(collateralToken.balanceOf(bob) < bobInitialCollBalance, "Collateral not taken");
        
        (address borrower,,uint256 loanAmount,,) = loanPair.loans(bob);
        assertEq(borrower, bob, "Loan not recorded");
        assertEq(loanAmount, 50e18, "Wrong loan amount");
        
        // Advance some blocks
        vm.roll(block.number + 10);
        
        uint256 preRepayBalance = loanToken.balanceOf(bob);
        // Bob repays
        loanPair.repay();
        
        (borrower,,loanAmount,,) = loanPair.loans(bob);
        assertEq(loanAmount, 0, "Loan not cleared");
        assertTrue(loanToken.balanceOf(bob) < preRepayBalance, "No interest paid");
        assertApproxEqRel(
            collateralToken.balanceOf(bob),
            bobInitialCollBalance,
            0.001e18,
            "Collateral not fully returned"
        );
        vm.stopPrank();
    }

    function test_BorrowAndLiquidate() public {
        uint256 aliceInitialLoanBalance = loanToken.balanceOf(alice);
        
        // Alice deposits into lending pool
        vm.startPrank(alice);
        loanPair.deposit(100e18);
        vm.stopPrank();
        
        uint256 bobInitialCollBalance = collateralToken.balanceOf(bob);
        
        // Bob borrows
        vm.startPrank(bob);
        loanPair.borrow(50e18);
        uint256 bobCollateralLocked = bobInitialCollBalance - collateralToken.balanceOf(bob);
        vm.stopPrank();
        
        // Change exchange rate to make loan underwater
        LoanPair(address(loanPair)).setMockExchangeRate(5e17); // 0.5, collateral worth less
        
        uint256 alicePreLiquidateCollateral = collateralToken.balanceOf(alice);
        
        // Alice liquidates Bob
        vm.startPrank(alice);
        loanPair.liquidate(bob);
        
        (,, uint256 loanAmount,,) = loanPair.loans(bob);
        assertEq(loanAmount, 0, "Loan not liquidated");
        assertTrue(
            collateralToken.balanceOf(alice) > alicePreLiquidateCollateral,
            "Liquidator didn't receive collateral"
        );
        assertEq(
            collateralToken.balanceOf(alice) - alicePreLiquidateCollateral,
            bobCollateralLocked,
            "Wrong collateral amount received"
        );
        vm.stopPrank();
    }
}