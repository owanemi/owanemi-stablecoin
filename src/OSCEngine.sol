// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwanemiStableCoin} from "./OwanemiStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Engine for our decentralized stablecoin
 * @author owanemi
 *
 * the system is designed to be as minimal as possible
 * to maintain $1 = 1 $OSC
 *
 * it is similar to DAI if DAI had no fees, and was only backed by
 * wETH and wBTC
 *
 * our OSC system should always be overcollateralized
 * At no point should the value of our collateral be <= dollar-backed value of all OSC
 *
 * @notice this contract is the core of OSC system. it handles all the logic
 * for minting and redeeming OSC. as well as depositing and withdrawing collateral
 * @notice this contract is very loosely based on the MakerDAO DSS (DAI) system
 */
contract OSCEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error OSCEngine__collateralAmountMustBeGreaterThanZero();
    error OSCEngine__unequalNumberOfTokenAddressAndPriceFeeds();
    error OSCEngine__tokenNotAllowed();
    error OSCEngine__TransferFailed();
    error OSCEngine__UserBreaksHealthFactor(uint256 healthFactor);
    error OSCEngine__MintFailed();
    error OSCEngine__HealthFactorOk();
    error OSCEngine__HealthFactorNotImproved();

    /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant DECIMAL_PRICE_PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // this means u need to be 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; //this means a 10% bonus

    OwanemiStableCoin private immutable i_osc;

    mapping(address tokenAddress => address priceFeed) private s_priceFeeds;
    mapping(address userAddress => mapping(address tokenAddress => uint256 amountDeposited)) private
        s_collateralDeposited;
    mapping(address userAddress => uint256 amountMinted) private s_mintedOscBalance;

    address[] private s_collateralTokens;
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralReedemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier moreThanZero(uint256 _amountCollateral) {
        if (_amountCollateral <= 0) {
            revert OSCEngine__collateralAmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert OSCEngine__tokenNotAllowed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL & PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address oscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert OSCEngine__unequalNumberOfTokenAddressAndPriceFeeds();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_osc = OwanemiStableCoin(oscAddress);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * DECIMAL_PRICE_PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function depositCollateralAndMintOsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountOscToMint
    ) public {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintOsc(amountOscToMint);
    }

    /**
     * @notice follows CEI -> checks, effects, integrations
     * @param tokenCollateralAddress is the address of the token that is to be deposited as the collateral
     * @param amountCollateral is the amount of collateral that is to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        if (!success) {
            revert OSCEngine__TransferFailed();
        }
    }

    /**
     * @notice follows CEI
     * @param oscAmountToMint the amount of owanemi stablecoin you wish to mint
     * @notice to mint osc, we check if collateral value > OSC amount
     * @notice they must have more collateral value than the minimum threshhold
     */
    function mintOsc(uint256 oscAmountToMint) public moreThanZero(oscAmountToMint) nonReentrant {
        s_mintedOscBalance[msg.sender] += oscAmountToMint;
        _revertIfHealthBalanceIsBroken(msg.sender);
        bool minted = i_osc.mint(msg.sender, oscAmountToMint);
        if (!minted) {
            revert OSCEngine__MintFailed();
        }
        _revertIfHealthBalanceIsBroken(msg.sender);
    }

    function redeemCollateralForOsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountOscToBurn)
        public
    {
        burnOsc(amountOscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
    }

    function burnOsc(uint256 amount) public moreThanZero(amount) {
        _burnOsc(amount, msg.sender, msg.sender);
        _revertIfHealthBalanceIsBroken(msg.sender);
    }

    function liquidate(address collateral, address user, uint256 debtToCover)
        public
        moreThanZero(debtToCover)
        nonReentrant
    {
        // we check the health factor of the user
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert OSCEngine__HealthFactorOk();
        }
        // we burn thier OSC "Debt" and remove their collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        // we give the liquidator 10% of the
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnOsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingHealthFactor) {
            revert OSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthBalanceIsBroken(msg.sender);
    }

    function getAccountCollateralValue(address userAddress) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited, and map it to the price to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[userAddress][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / DECIMAL_PRICE_PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalOScMinted, uint256 collateralValueInUsd)
    {
        (totalOScMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    /*//////////////////////////////////////////////////////////////
                     PRIVATE & INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _burnOsc(uint256 amountOscToBurn, address onBehalfOf, address oscFrom) private {
        s_mintedOscBalance[onBehalfOf] -= amountOscToBurn;
        bool success = i_osc.transferFrom(oscFrom, address(this), amountOscToBurn);

        if (!success) {
            revert OSCEngine__TransferFailed();
        }
        i_osc.burn(amountOscToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralReedemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);

        if (!success) {
            revert OSCEngine__TransferFailed();
        }
        _revertIfHealthBalanceIsBroken(msg.sender);
    }
    /**
     * @notice returns how close to liquidation a user is
     * if a user goes below 1, then they can get liquidated
     */

    function _getAccountInformation(address userAddress)
        private
        view
        returns (uint256 totalOscMinted, uint256 collateralValueInUsd)
    {
        totalOscMinted = s_mintedOscBalance[msg.sender];
        collateralValueInUsd = getAccountCollateralValue(userAddress);
    }

    function _healthFactor(address userAddress) internal view returns (uint256) {
        (uint256 totalOscMinted, uint256 collateralValueInUsd) = _getAccountInformation(userAddress);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_THRESHOLD;
        return (collateralAdjustedForThreshold * DECIMAL_PRICE_PRECISION) / totalOscMinted;
    }

    /**
     * @notice 1. check health factor(if they have enough collateral)
     * @notice 2. revert if they dont
     */
    function _revertIfHealthBalanceIsBroken(address userAddress) internal view {
        uint256 userHealthFactor = _healthFactor(userAddress);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert OSCEngine__UserBreaksHealthFactor(userHealthFactor);
        }
    }
}
