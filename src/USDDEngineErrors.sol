// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
/*//////////////////////////////////////////////////////////////
                                 ERRORS
//////////////////////////////////////////////////////////////*/

error NeedsMoreThanZero();
error TokenAddressesAndPriceFeedAddressesMustBeSameLength();
error TokenNotAllowed();
error TransferFailed();
error BreaksHealthFactor(uint256 healthFactor);
error MintFailed();
error HealthFactorOK();
error NegativePriceFeed();
error HealthFactorNotImproved();
error BurnAmountExceedsMinted();
error InsufficientCollateral();
