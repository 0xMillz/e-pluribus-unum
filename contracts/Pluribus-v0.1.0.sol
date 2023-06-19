// contracts/PluribusVault-v0.1.0.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/* 
 * Pluribus (UNUM) is an ERC20-compatible meta-stablecoin, collateralized by a basket of other popular USD stablecoins.
 * It allows the contract owner to dynamically update the allow-list of stablecoins that can be deposited as collateral.
 * Users can deposit collateral, mint UNUM, redeem UNUM, and withdraw their collateral. 
 * The contract keeps track of balances and allowances using mappings.
 */
contract Pluribus is ERC20 {
    // string public name; // Pluribus
    // string public symbol; // UNUM
    // uint8 public decimals; // 18
    // uint256 public totalSupply; // infinity?

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    ERC20[] public stablecoins;
    mapping(address => bool) public collateral;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event SupportedCollateralUpdated(address indexed stablecoin, bool isSupportedCollateral);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        ERC20[] memory _stablecoins
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        stablecoins = _stablecoins;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function updateSupportedCollateral(address stablecoin, bool isSupportedCollateral) external onlyOwner {
        require(isSupportedCollateral != collateral[stablecoin], "Collateral status already set");
        collateral[stablecoin] = isSupportedCollateral;
        emit SupportedCollateralUpdated(stablecoin, isSupportedCollateral);
    }

    function depositCollateral(uint256[] calldata amounts) external {
        require(amounts.length == stablecoins.length, "Invalid number of amounts");

        for (uint256 i = 0; i < stablecoins.length; i++) {
            require(collateral[address(stablecoins[i])], "Coin is not supported");

            stablecoins[i].transferFrom(msg.sender, address(this), amounts[i]);
            balances[msg.sender] += amounts[i];
            totalSupply += amounts[i];
        }

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function withdrawCollateral(uint256[] calldata amounts) external {
        require(amounts.length == stablecoins.length, "Invalid number of amounts");

        for (uint256 i = 0; i < stablecoins.length; i++) {
            require(balances[msg.sender] >= amounts[i], "Insufficient collateral balance");

            stablecoins[i].transfer(msg.sender, amounts[i]);
            balances[msg.sender] -= amounts[i];
            totalSupply -= amounts[i];
        }

        emit Transfer(msg.sender, address(0), totalSupply);
    }

    function mintStablecoins(uint256 amount) external {
        require(amount <= totalSupply, "Insufficient collateral value");

        uint256[] memory amounts = new uint256[](stablecoins.length);

        for (uint256 i = 0; i < stablecoins.length; i++) {
            amounts[i] = (amount * balances[msg.sender]) / totalSupply;
            require(amounts[i] <= balances[msg.sender], "Insufficient collateral balance");

            balances[msg.sender] -= amounts[i];
            stablecoins[i].transfer(msg.sender, amounts[i]);
        }

        totalSupply -= amount;
        balances[msg.sender] += amount;

        emit Transfer(address(0), msg.sender, amount);
    }

    function redeemStablecoins(uint256 amount) external {
        uint256[] memory amounts = new uint256[](stablecoins.length);

        for (uint256 i = 0; i < stablecoins.length; i++) {
            amounts[i] = (amount * balances[msg.sender]) / totalSupply;
            require(amounts[i] <= balances[msg.sender], "Insufficient stablecoin balance");

            balances[msg.sender] -= amounts[i];
            stablecoins[i].transferFrom(msg.sender, address(this), amounts[i]);
        }

        totalSupply += amount;
        balances[msg.sender] += amount;

        emit Transfer(msg.sender, address(0), amount);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(
            amount <= allowances[sender][msg.sender],
            "Transfer amount exceeds allowance"
        );
        allowances[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        require(amount <= balances[from], "Transfer amount exceeds balance");

        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }
}