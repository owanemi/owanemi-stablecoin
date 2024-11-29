// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {OwanemiStableCoin} from "../src/OwanemiStableCoin.sol";
import {OSCEngine} from "../src/OSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployOSCEngine is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (OwanemiStableCoin, OSCEngine) {
        HelperConfig config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        OwanemiStableCoin osc = new OwanemiStableCoin();
        OSCEngine engine = new OSCEngine(tokenAddresses, priceFeedAddresses, address(osc));

        osc.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (osc, engine);
    }
}
