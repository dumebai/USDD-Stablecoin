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
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployUSDD usddDeployer;
    USDDEngine usddEngine;
    USDDToken usddToken;
    HelperConfig helperConfig;
    address wEth;
    address wBtc;
    Handler handler;

    function setUp() external {
        usddDeployer = new DeployUSDD();
        (usddToken, usddEngine, helperConfig) = usddDeployer.run();
        (,, wEth, wBtc,) = helperConfig.activeNetworkConfig();
        // targetContract(address(usddEngine));

        // Don't call redeem collateral unless there is collateral to redeem -> create a handler.
        handler = new Handler(usddEngine, usddToken);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
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
