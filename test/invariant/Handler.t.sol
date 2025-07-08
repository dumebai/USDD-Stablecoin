// SPDX-License-Identifier: MIT
// Handler is going to narrow down the way we call function
// Sets the contract up

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {USDDToken} from "../../src/USDDToken.sol";
import {USDDEngine} from "../../src/USDDEngine.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

contract Handler is Test {
    USDDEngine usddEngine;
    USDDToken usddToken;

    ERC20Mock wEth;
    ERC20Mock wBtc;

    uint256 MIN_DEPOSIT_SIZE = 1e6;
    uint256 MAX_DEPOSIT_SIZE = 1_000_000 ether;

    constructor(USDDEngine _usddEngine, USDDToken _usddToken) {
        usddEngine = _usddEngine;
        usddToken = _usddToken;

        address[] memory collateralTokens = usddEngine.getCollateralTokens();
        wEth = ERC20Mock(collateralTokens[0]);
        wBtc = ERC20Mock(collateralTokens[1]);
    }

    // redeem collateral <-

    function depositCollateral( /*address collateral, */ uint256 collateralSeed, uint256 amountCollateral) public {
        //usddEngine.depositCollateral(collateral, amountCollateral);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 boundedAmount = bound(amountCollateral, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE); // (amount, min, max) reasonable limiting
        vm.startPrank(address(this));
        collateral.mint(address(this), boundedAmount);
        // Approve the engine to spend them
        collateral.approve(address(usddEngine), boundedAmount);
        usddEngine.depositCollateral(address(collateral), boundedAmount);
        vm.stopPrank();
    }

    // Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return wEth;
        }
        return wBtc;
    }
}
