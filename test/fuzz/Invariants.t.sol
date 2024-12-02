// were gonna otline our invariants here

// 1. the total supply of OSC should always be less than the total supply of collateral
// 2. our getter view functions should never revert

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {DeployOSCEngine} from "../../script/DeployOSCEngine.s.sol";
import {OSCEngine} from "../../src/OSCEngine.sol";
import {OwanemiStableCoin} from "../../src/OwanemiStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handlers.t.sol";

contract Invariants is StdInvariant, Test {
    DeployOSCEngine deployer;
    OSCEngine engine;
    OwanemiStableCoin osc;
    HelperConfig config;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployOSCEngine();
        (osc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // targetContract(address(engine));
        handler = new Handler(engine, osc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the debt in the
        uint256 totalSupply = osc.totalSupply();
        console.log("total supply is: ", totalSupply);

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethUsdValue = engine.getUsdValue(weth, totalWethDeposited);
        console.log("weth usd value is: ", wethUsdValue);

        uint256 wbtcUsdValue = engine.getUsdValue(wbtc, totalWbtcDeposited);
        console.log("wbtc usd value is: ", wbtcUsdValue);

        assert(wethUsdValue + wbtcUsdValue >= totalSupply);
    }
}
