// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/* 
 * Pluribus (UNUM) is an ERC20-compatible meta-stablecoin, collateralized by small basket of 4 other top USD stablecoins.
 * Users can deposit their stablecoins as collateral, mint UNUM, redeem UNUM, and withdraw their collateral by depositing 
 * the corresponding value of UNUM back into the contract to be burned.
*/
abstract contract Pluribus is ERC20 {
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

contract PriceOracle {
    // Chainlink Aggregator addresses for the tokens
    address public usdtUsdFeed;
    address public daiUsdFeed;
    address public usdcUsdFeed;
    address public fraxUsdFeed;

    constructor(
        address _usdtUsdFeed,
        address _daiUsdFeed,
        address _usdcUsdFeed,
        address _fraxUsdFeed
    ) {
        usdtUsdFeed = _usdtUsdFeed;
        daiUsdFeed = _daiUsdFeed;
        usdcUsdFeed = _usdcUsdFeed;
        fraxUsdFeed = _fraxUsdFeed;
    }

    function requestPrice(address token) external view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(getPriceFeed(token));
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Price not available");
        // Chainlink feeds return the price with 8 decimals, so divide by 1e8
        uint256 decimals = uint256(priceFeed.decimals());
        return uint256(price) / (10**decimals);
    }

    function getPriceFeed(address token) private view returns (address) {
        // TODO: verify price feed addresseses
        if (token == address(0x55d398326f99059fF775485246999027B3197955)) {
            // USDT/USD
            return usdtUsdFeed;
        } else if (token == address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063)) {
            // DAI/USD
            return daiUsdFeed;
        } else if (token == address(0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48)) {
            // USDC/USD
            return usdcUsdFeed;
        } else if (token == address(0x853d955aCEf822Db058eb8505911ED77F175b99e)) {
            // FRAX/USD
            return fraxUsdFeed;
        } else {
            revert("Invalid token");
        }
    }
}
