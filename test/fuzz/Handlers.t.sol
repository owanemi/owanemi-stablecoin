// Handler is going to narrow the way we call functions (so function calls will mimic real time scenario)

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {OSCEngine} from "../../src/OSCEngine.sol";
import {OwanemiStableCoin} from "../../src/OwanemiStableCoin.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    OSCEngine engine;
    OwanemiStableCoin osc;
    
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_AMOUNT = type(uint96).max;

    constructor(OSCEngine _engine, OwanemiStableCoin _osc) {
        engine = _engine;
        osc = _osc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_AMOUNT);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));
        console.log("max to reedeem : %s", maxCollateralToRedeem);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if(amountCollateral == 0) {
            return;
        }
        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    // this will make sure a valid collateral is selected no matter what bcos the collateralSeed can take any no.
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if(collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
