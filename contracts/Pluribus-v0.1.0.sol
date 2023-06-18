// contracts/PluribusVault-v0.1.0.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Pluribus {
    mapping(address => uint256) public balances; // Balances of each user

    IERC20[] public stablecoins; // List of stablecoins
    uint256 public totalCollateral; // Total value of collateral

    // Event triggered when a user deposits collateral
    event CollateralDeposited(address indexed user, uint256 amount);

    // Event triggered when a user withdraws collateral
    event CollateralWithdrawn(address indexed user, uint256 amount);

    // Event triggered when a user mints stablecoins
    event StablecoinsMinted(address indexed user, uint256 amount);

    // Event triggered when a user redeems stablecoins
    event StablecoinsRedeemed(address indexed user, uint256 amount);

    constructor(IERC20[] memory _stablecoins) {
        stablecoins = _stablecoins;
    }

    // Deposits collateral by transferring stablecoins to the contract
    function depositCollateral(uint256[] memory amounts) external {
        require(amounts.length == stablecoins.length, "Invalid number of amounts");

        for (uint256 i = 0; i < stablecoins.length; i++) {
            stablecoins[i].transferFrom(msg.sender, address(this), amounts[i]);
            balances[msg.sender] += amounts[i];
            totalCollateral += amounts[i];
        }

        emit CollateralDeposited(msg.sender, totalCollateral);
    }

    // Withdraws collateral by transferring stablecoins from the contract to the user
    function withdrawCollateral(uint256[] memory amounts) external {
        require(amounts.length == stablecoins.length, "Invalid number of amounts");

        for (uint256 i = 0; i < stablecoins.length; i++) {
            require(balances[msg.sender] >= amounts[i], "Insufficient collateral balance");

            stablecoins[i].transfer(msg.sender, amounts[i]);
            balances[msg.sender] -= amounts[i];
            totalCollateral -= amounts[i];
        }

        emit CollateralWithdrawn(msg.sender, totalCollateral);
    }

    // Mints stablecoins by transferring an equivalent amount of collateral to the contract
    function mintStablecoins(uint256 amount) external {
        uint256 basketValue = calculateBasketValue();
        require(amount <= basketValue, "Insufficient collateral value");

        uint256[] memory amounts = new uint256[](stablecoins.length);

        for (uint256 i = 0; i < stablecoins.length; i++) {
            amounts[i] = (amount * balances[msg.sender]) / basketValue;
            require(amounts[i] <= balances[msg.sender], "Insufficient collateral balance");

            balances[msg.sender] -= amounts[i];
            stablecoins[i].transfer(msg.sender, amounts[i]);
        }

        emit StablecoinsMinted(msg.sender, amount);
    }

    // Redeems stablecoins by transferring an equivalent amount of collateral from the user to the contract
    function redeemStablecoins(uint256 amount) external {
        uint256[] memory amounts = new uint256[](stablecoins.length);

        for (uint256 i = 0; i < stablecoins.length; i++) {
            amounts[i] = (amount * balances[msg.sender]) / totalCollateral;
            require(amounts[i] <= balances[msg.sender], "Insufficient collateral balance");

            balances[msg.sender] -= amounts[i];
            stablecoins[i].transferFrom(msg.sender, address(this), amounts[i]);
        }

        emit StablecoinsRedeemed(msg.sender, amount);
    }

    // Calculates the total value of collateral in the basket
    function calculateBasketValue() public view returns (uint256) {
        uint256 basketValue = 0;

        for (uint256 i = 0; i < stablecoins.length; i++) {
            basketValue += stablecoins[i].balanceOf(address(this));
        }

        return basketValue;
    }
}