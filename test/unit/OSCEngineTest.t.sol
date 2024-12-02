// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOSCEngine} from "../../script/DeployOSCEngine.s.sol";
import {OwanemiStableCoin} from "../../src/OwanemiStableCoin.sol";
import {OSCEngine} from "../../src/OSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

contract OSCEngineTest is Test {
    DeployOSCEngine deployer;
    OwanemiStableCoin osc;
    OSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC_20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployOSCEngine();
        (osc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC_20_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDontMatchPriceFeed() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(OSCEngine.OSCEngine__unequalNumberOfTokenAddressAndPriceFeeds.selector);
        new OSCEngine(tokenAddresses, priceFeedAddresses, address(osc));
    }

    /*//////////////////////////////////////////////////////////////
                              PRICE TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /*//////////////////////////////////////////////////////////////
                              depositCollateral TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(OSCEngine.OSCEngine__collateralAmountMustBeGreaterThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock("RAND", "RAND", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(OSCEngine.OSCEngine__tokenNotAllowed.selector);
        engine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalOscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalOscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalOscMinted, expectedTotalOscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }
}
