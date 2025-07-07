// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployUSDD} from "../../script/DeployUSDD.s.sol";
import {USDDToken} from "../../src/USDDToken.sol";
import {USDDEngine} from "../../src/USDDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";
import "../../src/USDDEngineErrors.sol" as USDDEngineErrors;

contract USDDEngineTest is Test {
    DeployUSDD deployer;
    USDDToken usddToken;
    USDDEngine usddEngine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployUSDD();
        (usddToken, usddEngine, config) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            PRICE FEED TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = usddEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(usddEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(USDDEngineErrors.NeedsMoreThanZero.selector);
        usddEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
