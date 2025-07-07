// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {USDDToken} from "../src/USDDToken.sol";
import {USDDEngine} from "../src/USDDEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployUSDD is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (USDDToken, USDDEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address ethUsdPriceFeed, address btcUsdPriceFeed, address weth, address wbtc, address account) =
            config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [ethUsdPriceFeed, btcUsdPriceFeed];

        vm.startBroadcast(account);

        USDDToken usddToken = new USDDToken(account);
        USDDEngine usddEngine = new USDDEngine(tokenAddresses, priceFeedAddresses, address(usddToken));

        usddToken.transferOwnership(address(usddEngine));

        vm.stopBroadcast();

        return (usddToken, usddEngine, config);
    }
}
