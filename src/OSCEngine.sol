// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

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
 * 
 * @notice this contract is the core of OSC system. it handles all the logic
 * for minting and redeeming OSC. as well as depositing and withdrawing collateral
 * @notice this contract is very loosely based on the MakerDAO DSS (DAI) system
 */
contract OSCEngine {
    function depositCollateralAndMintOsc() public view {}

    function redeeemCollateralForOsc() public view {}

    function burnOsc() public view {}


}