// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// IMPORTS
import {USDDToken} from "./USDDToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./USDDEngineErrors.sol" as USDDEngineErrors;

/*
 * @title USDD Token
 * @author dumebai
 *
 * The system is designed to be as minimal as possible
 * and have the tokens maintain a 1 token == $ 1 peg.
 *
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees
 * and was only backed by wETH and wBTC.
 *
 * USDD system should be "overcollateralized".
 * At no point should the value of all collateral <= the $ backed value of all the USDD.
 *
 * @notice This contract is the core of USDD System.
 * @notice It handles all the logic for minting and redeeming,
 * as well as depositing and withdrawing collateral.
 *
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */

// @dev: ERC20Burnable has _burn function
contract USDDEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_TRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATOR_BONUS = 10; // this means a 10%

    mapping(address token => address priceFeed) private s_priceFeeds; // s_tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountUsddMinted) private s_usddMinted;
    address[] private s_collateralTokens;

    USDDToken private immutable i_usdd;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed tokenCollateralAddress, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert USDDEngineErrors.NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert USDDEngineErrors.TokenNotAllowed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address usddAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert USDDEngineErrors.TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        // For example ETH / USD, BTC / USD, MKR / USD, etc.
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_usdd = USDDToken(usddAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
     * @param tokenCollateralAddress - the address of the token to deposit as collateral.
     * @param amountCollateral - the amount of collateral to deposit.
     * @param amountUsddToMint - the amount of USDD stablecoin to mint.
     * @notice This function will deposit your collateral and mint USDD in one transaction.
     */
    function depositCollateralAndMint(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountUsddToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mint(amountUsddToMint);
    }

    /*
     * @notice Function follows CEI pattern (checks-effects-interactions)
     * @param tokenCollateralAddress - the address of token to deposit as collateral.
     * @param amountCollateral - the amount of collateral to deposit.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert USDDEngineErrors.TransferFailed();
        }
    }

    /*
     * @notice Function follows CEI pattern (checks-effects-interactions)
     * @param amountUsddToMint - the amount of USDD stablecoin to mint.
     * @notice User must haves collateral value than the minimum treshold.
     */
    function mint(uint256 amountUsddToMint) public moreThanZero(amountUsddToMint) nonReentrant {
        s_usddMinted[msg.sender] += amountUsddToMint;
        // If they minted too much (ex: $150 USDD, $100 ETH), revert.
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_usdd.mint(msg.sender, amountUsddToMint);
        if (!minted) {
            revert USDDEngineErrors.MintFailed();
        }
    }

    // In order to redeem collateral:
    // Health Factor must be over 1 after collateral pulled.
    // DRY: Don't repeat yourself.
    // TODO: REFACTOR!!!
    // @notice Function follows CEI pattern (checks-effects-interactions)
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress - The collateral address to redeem.
     * @param amountCollateral - The amount of collateral to redeem.
     * @param amountUsddToBurn - The amount of USDD to burn.
     * This function burns USDD and redeems underlying collateral in one transaction.
     */
    function redeemCollateralForUSDD(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountUsddToBurn)
        external
    {
        burn(amountUsddToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks health factor
    }

    // Threshold to 150%
    // $100 wETH Collateral -> $74 wETH
    // $50 USDD
    // UNDERCOLLATERALIZED!!!

    // Other user can pay back the $50 USDD -> gets all collateral of undercollateralized user.

    function burn(uint256 amount) public moreThanZero(amount) {
        _burn(msg.sender, msg.sender, amount);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    // If someone is almost undercollateralized, we will pay other user to liquidate them.
    /*
     * @param collateral - The ERC20 collateral address to liquidate from the user.
     * @param user - The user who has broken the health factor. Their _healthFactor
     * should be below MIN_HEALTH_FACTOR.
     * @param debtToCover - The amount of USDD to be burnt to improve users health factor.
     *
     * @notice You can partially liquidate a user.
     * @notice You will get a liquidation bonus for taking users funds.
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized
     * in order for this to work.
     * @notice A known bug would be if the protocol were 100% or less collateralized - then it
     * wouldn't be able to incentivize the liquidators.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     *
     * @notice Function follows CEI pattern (checks-effects-interactions)
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // check health factor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert USDDEngineErrors.HealthFactorOK();
        }
        // we want to burn their USDD "debt"
        // and take their collateral
        // Bad Actor: $140 ETH, $100 USDD
        // debtToCover = $100
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // incentivize with 10% bonus
        // 0.05 * 0.1 = 0.005 ETH - liquidator gets 0.055 ETH
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);

        // burn USDD
        _burn(user, msg.sender, debtToCover);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert USDDEngineErrors.HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);

        // TODO: Implement a feature to liquidate in the event the protocol is insolvent.
        // TODO: Sweep extra amounts into a treasury.
    }

    /*//////////////////////////////////////////////////////////////
                    PRIVATE & INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
     * @dev Low-level internal function. Do not call unless the function
     * calling it is checking for health factors being broken.
     */
    function _burn(address onBehalfOf, address usddFrom, uint256 amountUsddToBurn) private {
        if (s_usddMinted[onBehalfOf] < amountUsddToBurn) {
            revert USDDEngineErrors.BurnAmountExceedsMinted();
        }
        s_usddMinted[onBehalfOf] -= amountUsddToBurn;
        bool success = i_usdd.transferFrom(usddFrom, address(this), amountUsddToBurn);
        if (!success) {
            revert USDDEngineErrors.TransferFailed();
        }
        i_usdd.burn(amountUsddToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        // Mitigate underflow by checking if there's enough collateral to redeem.
        if (s_collateralDeposited[from][tokenCollateralAddress] < amountCollateral) {
            revert USDDEngineErrors.InsufficientCollateral();
        }
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        // _calculateHealthFactorAfter(); - gas innefficient.
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert USDDEngineErrors.TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalUsddMinted, uint256 collateralValueInUsd)
    {
        totalUsddMinted = s_usddMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
     * Returns how close to liquidation a user is.
     * If a user goes below 1, then they can get liquidated.
     */
    function _healthFactor(address user) private view returns (uint256) {
        // Total USDD minted.
        // Total collateral VALUE.
        (uint256 totalUsddMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        // If totalUsddMinted == 0, it's gonna revert due to division by zero.
        if (totalUsddMinted == 0) {
            return type(uint256).max; // no debt = perfect health
        }

        uint256 collateralAdjustedForTreshold = (collateralValueInUsd * LIQUIDATION_TRESHOLD) / LIQUIDATION_PRECISION;
        // $1000 wETH * 50 = 50,000 / 100 = 500
        // 500 / 100 USDD = 5 > 1
        return (collateralAdjustedForTreshold * PRECISION) / totalUsddMinted;
    }

    // 1. Check health factor (do they have enough collateral).
    // 2. Revert if they don't have a good health factor.
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert USDDEngineErrors.BreaksHealthFactor(userHealthFactor);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC & EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through each collateral token, get the amount they have deposited, and map it to the price to get USD value.
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getPriceFeed(address token) public view isAllowedToken(token) returns (int256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, price,,,) = priceFeed.latestRoundData();
        if (price < 0) {
            revert USDDEngineErrors.NegativePriceFeed();
        }
        return price;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        int256 price = getPriceFeed(token);

        // 1 ETH = $1000
        // The returned value from ChainLink will be 1000 * 1e8 (has 8 decimals)
        // https://docs.chain.link/data-feeds/price-feeds/addresses

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH (or other token)
        int256 price = getPriceFeed(token);
        // $2000 ETH. $1000 worth = 0.5 ETH
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }
}
