// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwanemiStableCoin} from "./OwanemiStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

    mapping(address tokenAddress => address priceFeed) private s_priceFeeds;
    mapping(address userAddress => mapping(address tokenAddress => uint256 amountDeposited)) private
        s_collateralDeposited;

    OwanemiStableCoin private immutable i_osc;

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
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address oscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert OSCEngine__unequalNumberOfTokenAddressAndPriceFeeds();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
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

        if(!success) {
            revert OSCEngine__TransferFailed();
        }
    }

    function redeeemCollateralForOsc() public view {}

    function redeemCollateral() public view {}

    function burnOsc() public view {}

    function liquidate() public view {}

    function getHealthFactor() external view {}
}
