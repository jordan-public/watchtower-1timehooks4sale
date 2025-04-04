// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ILoanPair} from "./interfaces/ILoanPair.sol";

contract LoanPair is ILoanPair {
    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;

    // Vault state
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    
    // Lending state
    uint256 public interestPerBlock;
    mapping(address => Loan) public loans;
    uint256 public collateralizationRatio;
    
    // Mock exchange rate (1:1 for simplicity)
    uint256 public constant MOCK_EXCHANGE_RATE = 1e18;

    constructor(
        IERC20 _loanToken, 
        IERC20 _collateralToken
    ) {
        require(address(_loanToken) != address(0), "Invalid loan token");
        require(address(_collateralToken) != address(0), "Invalid collateral token");
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        setInterestRate(100); // 10% interest per block
        setCollateralizationRatio(150); // 150% collateralization ratio
    }

    function setInterestRate(uint256 _interestPerBlock) public {
        interestPerBlock = _interestPerBlock;
    }

    function setCollateralizationRatio(uint256 _ratio) public {
        require(_ratio >= 100, "Ratio must be >= 100%");
        collateralizationRatio = _ratio;
    }

    function deposit(uint256 amount) external returns (uint256) {
        require(amount > 0, "Cannot deposit 0");
        uint256 sharesAmount = totalShares == 0 
            ? amount 
            : (amount * totalShares) / totalLoanTokens();

        totalShares += sharesAmount;
        shares[msg.sender] += sharesAmount;

        require(loanToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Deposit(msg.sender, amount, sharesAmount);
        return sharesAmount;
    }

    function withdraw(uint256 sharesAmount) external returns (uint256) {
        require(sharesAmount > 0, "Cannot withdraw 0");
        require(shares[msg.sender] >= sharesAmount, "Insufficient shares");

        uint256 amount = (sharesAmount * totalLoanTokens()) / totalShares;
        require(availableLoanTokens() >= amount, "Insufficient liquidity");

        shares[msg.sender] -= sharesAmount;
        totalShares -= sharesAmount;

        require(loanToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(msg.sender, amount, sharesAmount);
        return amount;
    }

    function borrow(uint256 loanAmount) external {
        require(loanAmount > 0, "Cannot borrow 0");
        require(loans[msg.sender].loanAmount == 0, "Existing loan must be repaid");
        require(availableLoanTokens() >= loanAmount, "Insufficient liquidity");

        uint256 collateralRequired = (loanAmount * collateralizationRatio * MOCK_EXCHANGE_RATE) / 1e20;
        
        loans[msg.sender] = Loan({
            borrower: msg.sender,
            initiationTime: block.number,
            loanAmount: loanAmount,
            collateralAmount: collateralRequired,
            interestPerBlock: interestPerBlock
        });

        require(collateralToken.transferFrom(msg.sender, address(this), collateralRequired), "Collateral transfer failed");
        require(loanToken.transfer(msg.sender, loanAmount), "Loan transfer failed");

        emit Borrow(msg.sender, loanAmount, collateralRequired);
    }

    function repay() external {
        Loan storage loan = loans[msg.sender];
        require(loan.loanAmount > 0, "No active loan");

        uint256 blocksPassed = block.number - loan.initiationTime;
        uint256 interest = (loan.loanAmount * loan.interestPerBlock * blocksPassed) / 1e18;
        uint256 totalRepayment = loan.loanAmount + interest;

        require(loanToken.transferFrom(msg.sender, address(this), totalRepayment), "Repayment failed");
        require(collateralToken.transfer(msg.sender, loan.collateralAmount), "Collateral return failed");

        emit Repay(msg.sender, totalRepayment, loan.collateralAmount);
        delete loans[msg.sender];
    }

    // View functions
    function totalLoanTokens() public view returns (uint256) {
        return loanToken.balanceOf(address(this));
    }

    function availableLoanTokens() public view returns (uint256) {
        uint256 totalLoaned;
        // Note: This is a simplified version. In production, you'd track total borrowed separately
        return totalLoanTokens() - totalLoaned;
    }
}