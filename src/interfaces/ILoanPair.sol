// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWatchtower} from "./IWatchtower.sol";

interface ILoanPair {
    struct Loan {
        address borrower;
        uint256 initiationTime;
        uint256 loanAmount;
        uint256 collateralAmount;
        uint256 interestPerBlock;
    }

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event Borrow(address indexed borrower, uint256 loanAmount, uint256 collateralAmount);
    event Repay(address indexed borrower, uint256 repaidAmount, uint256 collateralReturned);
    event Liquidate(address indexed borrower, address indexed liquidator, uint256 repayAmount, uint256 collateralAmount);

    function loanToken() external view returns (IERC20);
    function collateralToken() external view returns (IERC20);
    function totalShares() external view returns (uint256);
    function shares(address account) external view returns (uint256);
    function loans(address _borrower) external view returns (
        address borrower,
        uint256 initiationTime,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 interestPerBlock
    );
    function interestPerBlock() external view returns (uint256);

    function setInterestRate(uint256 _interestPerBlock) external;
    function setInitCollateralizationRatio(uint256 _ratio) external;
    function setMinCollateralizationRatio(uint256 _ratio) external;
    function setLiquidationPenaltyRatio(uint256 _ratio) external;
    function getCurrentCollateralizationRatio(address borrower) external view returns (uint256);
    function deposit(uint256 amount) external returns (uint256);
    function withdraw(uint256 sharesAmount) external returns (uint256);
    function borrow(uint256 loanAmount) external;
    function repay() external;
    function liquidate(address borrower) external;
    function totalLoanTokens() external view returns (uint256);
    function availableLoanTokens() external view returns (uint256);
}