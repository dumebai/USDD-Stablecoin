// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
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
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployUSDD();
        (usddToken, usddEngine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(USDDEngineErrors.TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new USDDEngine(tokenAddresses, priceFeedAddresses, address(usddToken));
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

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWEth = 0.05 ether;
        uint256 actualWEth = usddEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWEth, actualWEth);
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

    function testRevertsWithUnnaprovedCollateral() public {
        ERC20Mock badToken = new ERC20Mock("BAD Token", "BAD", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(USDDEngineErrors.TokenNotAllowed.selector);
        usddEngine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(usddEngine), AMOUNT_COLLATERAL);
        usddEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalUsddMinted, uint256 collateralValueInUsd) = usddEngine.getAccountInformation(USER);
        console.log("TOTAL USDD MINTED: ", totalUsddMinted);
        console.log("TOTAL COLLATERAL VALUE IN USD: ", totalUsddMinted);
        uint256 expectedTotalUsddMinted = 0;
        uint256 expectedCollateralValueInUsd = usddEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        console.log("EXPECTED USDD MINTED: ", expectedTotalUsddMinted);
        console.log("EXPECTED COLLATERAL VALUE IN USD: ", expectedCollateralValueInUsd);
        assertEq(totalUsddMinted, expectedTotalUsddMinted);
        assertEq(AMOUNT_COLLATERAL, expectedCollateralValueInUsd);
    }

    // TODO: MORE TESTS
}
