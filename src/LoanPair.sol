// SPDX-License-Identifier: BUSL-1.1
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
    uint256 public initCollateralizationRatio;
    uint256 public minCollateralizationRatio;
    uint256 public liquidationPenaltyRatio;
    
    // Exchange rate state
    uint256 private mockExchangeRate;

    constructor(
        IERC20 _loanToken, 
        IERC20 _collateralToken
    ) {
        require(address(_loanToken) != address(0), "Invalid loan token");
        require(address(_collateralToken) != address(0), "Invalid collateral token");
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        setInterestRate(100); // 10% interest per block
        setInitCollateralizationRatio(150); // 150% initial collateralization ratio
        setMinCollateralizationRatio(110); // 110% minimum collateralization ratio
        setLiquidationPenaltyRatio(50); // 5% liquidation penalty
        mockExchangeRate = 1e18; // Initial 1:1 exchange rate
    }

    function setInterestRate(uint256 _interestPerBlock) public {
        interestPerBlock = _interestPerBlock;
    }

    function setInitCollateralizationRatio(uint256 _ratio) public {
        require(_ratio >= 100, "Ratio must be >= 100%");
        require(_ratio > minCollateralizationRatio, "Must be > min ratio");
        initCollateralizationRatio = _ratio;
    }

    function setMinCollateralizationRatio(uint256 _ratio) public {
        require(_ratio >= 100, "Ratio must be >= 100%");
        require(_ratio < initCollateralizationRatio, "Must be < init ratio");
        minCollateralizationRatio = _ratio;
    }

    function setLiquidationPenaltyRatio(uint256 _ratio) public {
        require(_ratio > 0, "Ratio must be > 0");
        liquidationPenaltyRatio = _ratio;
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

        uint256 collateralRequired = (loanAmount * initCollateralizationRatio * getExchangeRate()) / 1e20;
        
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

    function getCurrentCollateralizationRatio(address borrower) public view returns (uint256) {
        Loan storage loan = loans[borrower];
        require(loan.loanAmount > 0, "No active loan");
        
        uint256 blocksPassed = block.number - loan.initiationTime;
        uint256 interest = (loan.loanAmount * loan.interestPerBlock * blocksPassed) / 1e18;
        uint256 totalOwed = loan.loanAmount + interest;
        
        return (loan.collateralAmount * 1e18) / (totalOwed * getExchangeRate());
    }

    function liquidate(address borrower) external {
        Loan storage loan = loans[borrower];
        require(loan.loanAmount > 0, "No active loan");
        
        uint256 currentRatio = getCurrentCollateralizationRatio(borrower);
        require(currentRatio < minCollateralizationRatio, "Not liquidatable");

        uint256 blocksPassed = block.number - loan.initiationTime;
        uint256 interest = (loan.loanAmount * loan.interestPerBlock * blocksPassed) / 1e18;
        uint256 totalOwed = loan.loanAmount + interest;
        
        // Calculate liquidation penalty
        uint256 penalty = (totalOwed * liquidationPenaltyRatio) / 1000;
        uint256 totalRequired = totalOwed + penalty;

        // Transfer loan tokens from liquidator
        require(loanToken.transferFrom(msg.sender, address(this), totalRequired), "Liquidation payment failed");
        
        // Transfer collateral to liquidator
        require(collateralToken.transfer(msg.sender, loan.collateralAmount), "Collateral transfer failed");

        emit Liquidate(borrower, msg.sender, totalRequired, loan.collateralAmount);
        delete loans[borrower];
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

    function getExchangeRate() public view returns (uint256) {
        return mockExchangeRate;
    }

    function setMockExchangeRate(uint256 _rate) external {
        require(_rate > 0, "Invalid exchange rate");
        mockExchangeRate = _rate;
    }
}