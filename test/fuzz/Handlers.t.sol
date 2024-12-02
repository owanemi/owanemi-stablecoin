// Handler is going to narrow the way we call functions (so function calls will mimic real time scenario)

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {OSCEngine} from "../../src/OSCEngine.sol";
import {OwanemiStableCoin} from "../../src/OwanemiStableCoin.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    OSCEngine engine;
    OwanemiStableCoin osc;
    
    ERC20Mock weth;
    ERC20Mock wbtc;

    constructor(OSCEngine _engine, OwanemiStableCoin _osc) {
        engine = _engine;
        osc = _osc;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        engine.depositCollateral(collateralSeed, amountCollateral);
    }

    function _getCollateralFromSeed() private view returns (ERC20Mock) {
        if(collateralSeed % 2 == 0) {
            return weth;
        }
    }
}
