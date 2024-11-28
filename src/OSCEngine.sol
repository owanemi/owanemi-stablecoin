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

    /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant DECIMAL_PRICE_PRECISION = 1e18;

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
                              EXTERNAL FUNCTIONS
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

    function depositCollateralAndMintOsc() public view {}

    /**
     * @notice follows CEI -> checks, effects, integrations
     * @param tokenCollateralAddress is the address of the token that is to be deposited as the collateral
     * @param amountCollateral is the amount of collateral that is to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
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
    function mintOsc(uint256 oscAmountToMint) moreThanZero(oscAmountToMint) nonReentrant {
        s_mintedOscBalance[msg.sender] += oscAmountToMint;
    }

    function redeeemCollateralForOsc() public view {}

    function redeemCollateral() public view {}

    function burnOsc() public view {}

    function liquidate() public view {}

    function getHealthFactor() external view {}

    /*//////////////////////////////////////////////////////////////
                     PRIVATE & INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice returns how close to liquidation a user is
     * if a user goes below 1, then they can get liquidated
     * @param userAddress
     */
    function _getAccountInformation(address userAddress)
        private
        view
        returns (uint256 totalOscMinted, uint256 collateralValueinUsd)
    {
        totalOscMinted = s_mintedOscBalance[msg.sender];
        collateralValueinUsd = getAccountCollateralValue(userAddress);
    }

    function _healthFactor(address userAddress) internal view returns (uint256) {}

    function _revertIfHealthBalanceIsBroken(address userAddress) internal view {
        // 1. check health factor(if they have enough collateral)
        // 2. revert if they dont
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC & EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAccountCollateralValue(address userAddress) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited, and map it to the price to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[userAddress][token];
            totalCollateralValueInUsd += getAccountCollateralValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * DECIMAL_PRICE_PRECISION) / 1e18;
    }
}
