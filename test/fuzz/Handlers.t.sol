// Handler is going to narrow the way we call functions (so function calls will mimic real time scenario)

// SPDX-License-Identifier: MIT
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

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

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
        // usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    // function mintOsc(uint256 amount, uint256 addressSeed) public {
    //     if (usersWithCollateralDeposited.length == 0) {
    //         return;
    //     }
    //     address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
    //     (uint256 totalOscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);

    //     int256 maxOscToMint = int256((collateralValueInUsd / 2)) - int256(totalOscMinted);
    //     if(maxOscToMint < 0) {
    //         return;
    //     }
    //     // amount = bound(amount, 1, MAX_DEPOSIT_AMOUNT);
    //     amount = bound(amount, 0, uint256(maxOscToMint));
    //     if(amount == 0) {
    //         return;
    //     }
    //     vm.startPrank(sender);
    //     engine.mintOsc(amount);
    //     vm.stopPrank();
    //     timesMintIsCalled++;
    // }

    // this will make sure a valid collateral is selected no matter what bcos the collateralSeed can take any no.
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
