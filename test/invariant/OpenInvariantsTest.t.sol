// SPDX-License-Identifier: MIT
// Invariants - properties that should always hold.

pragma solidity ^0.8.18;

// What are our invariants?

// 1. The total supply of USDD should be less than the total value of collateral

// 2. Getter view functions should never revert <- evergreen invariant

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployUSDD} from "../../script/DeployUSDD.s.sol";
import {USDDToken} from "../../src/USDDToken.sol";
import {USDDEngine} from "../../src/USDDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DeployUSDD usddDeployer;
    USDDEngine usddEngine;
    USDDToken usddToken;
    HelperConfig helperConfig;
    address wEth;
    address wBtc;

    function setUp() external {
        usddDeployer = new DeployUSDD();
        (usddToken, usddEngine, helperConfig) = usddDeployer.run();
        (,, wEth, wBtc,) = helperConfig.activeNetworkConfig();
        targetContract(address(usddEngine));
    }

    function invariant_openProtocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the debt (usdd)
        uint256 totalSupply = usddToken.totalSupply();
        uint256 totalWEthDeposited = IERC20(wEth).balanceOf(address(usddEngine));
        uint256 totalWBtcDeposited = IERC20(wBtc).balanceOf(address(usddEngine));

        uint256 wEthValue = usddEngine.getUsdValue(wEth, totalWEthDeposited);
        uint256 wBtcValue = usddEngine.getUsdValue(wBtc, totalWBtcDeposited);

        assert(wEthValue + wBtcValue >= totalSupply);
    }
}
