// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title USDD Token
 * @author dumebai
 *
 * Collateral: Exogenous (wETH / wBTC)
 * Minting: Alogrithmic
 * Relative stability: Pegged to USD
 *
 * This is the contract meant to be governed by USDDEngine.
 * This contract is just the ERC20 implementation of our stablecoin system.
 */

// @dev: ERC20Burnable has _burn function
contract USDDToken is ERC20Burnable, Ownable {
    error USDDToken__MustBeMoreThanZero();
    error USDDToken__BurnAmountExceedsBalance();
    error USDDToken__NotZeroAddress();

    constructor(address _owner) ERC20("USDDToken", "USDD") Ownable(_owner) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert USDDToken__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert USDDToken__BurnAmountExceedsBalance();
        }
        // super keyword basically says:
        // use the burn function from the parent class
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert USDDToken__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert USDDToken__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
