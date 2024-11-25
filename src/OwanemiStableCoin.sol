// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

error OwanemiStableCoin__invalidAmountEntered();
error OwanemiStableCoin__amountGreaterThanBalance();
error OwanemiStableCoin__NotZeroAddress();

/**
 * @title Decentralized stable coin
 * @author owanemi
 * Collateralization: Exogeneous
 * Minting-Mechanism: algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by Owanemi Stable Coin engine
 * This contract is just the ERC-20 implementation of our stablecoin
 */
contract OwanemiStableCoin is ERC20Burnable, Ownable {
    constructor() ERC20("OwanemiStableCoin", "OSC") {}

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert OwanemiStableCoin__NotZeroAddress();
        }

        if (_amount <= 0) {
            revert OwanemiStableCoin__invalidAmountEntered();
        }

        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert OwanemiStableCoin__invalidAmountEntered();
        }

        if (_amount > balance) {
            revert OwanemiStableCoin__amountGreaterThanBalance();
        }

        super.burn(_amount);
    }
}
