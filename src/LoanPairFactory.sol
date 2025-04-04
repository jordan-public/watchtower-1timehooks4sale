// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ILoanPair} from "./interfaces/ILoanPair.sol";
import {LoanPair} from "./LoanPair.sol";

contract LoanPairFactory {
    /// Array to store all created loan pairs
    LoanPair[] public loanPairs;

    // Mapping to find LoanPair by token pair
    mapping(IERC20 => mapping(IERC20 => ILoanPair)) public tokensToLoanPair;

    event LoanPairCreated(address indexed loanPair, IERC20 indexed loanToken, IERC20 indexed collateralToken);

    function createLoanPair(
        IERC20 loanToken, 
        IERC20 collateralToken
    ) external returns (ILoanPair) {
        require(address(loanToken) != address(0), "Loan token cannot be zero address");
        require(address(collateralToken) != address(0), "Collateral token cannot be zero address");
        require(tokensToLoanPair[loanToken][collateralToken] == ILoanPair(address(0)), "LoanPair already exists");

        LoanPair loanPair = new LoanPair(
            loanToken, 
            collateralToken
        );

        loanPairs.push(loanPair);

        tokensToLoanPair[loanToken][collateralToken] = ILoanPair(loanPair);

        emit LoanPairCreated(address(loanPair), loanToken, collateralToken);

        return ILoanPair(loanPair);
    }

    function getLoanPair(IERC20 loanToken, IERC20 collateralToken) external view returns (ILoanPair) {
        return tokensToLoanPair[loanToken][collateralToken];
    }

    function getLoanPairsCount() external view returns (uint256) {
        return loanPairs.length;
    }
}