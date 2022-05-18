/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token TAXABLETOKEN contract
///
/// @author John Daugherty
///
contract TaxableToken is AccessControl {
    // Influencers For Change tax information
    address private _taxWallet = address(0);
    uint private _taxAmount = 1; // 1%

    function taxWallet()
    internal
    view
    returns (address)
    {
        return _taxWallet;
    }

    function taxAmount()
    internal
    view
    returns (uint)
    {
        return _taxAmount;
    }

    /// @notice Updates the tax wallet address.
    ///
    /// @dev Checks that the new address is not 0, then sets the tax wallet.
    ///
    /// Requirements:
    /// - Must have TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param taxWalletAddress The new tax wallet address.
    /// @return Whether the tax wallet address was successfully set.
    function setTaxWallet(address taxWalletAddress)
    public
    onlyRole(Constants.TAX_ADMIN)
    returns (bool)
    {
        require (taxWalletAddress != address(0), "TTM: Attempt to set tax wallet to address: 0");

        _taxWallet = taxWalletAddress;

        return true;
    }

    /// @notice Gets the tax wallet address.
    ///
    /// Requirements:
    /// - Must have TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current tax wallet address.
    function getTaxWallet() 
    public
    view
    onlyRole(Constants.TAX_ADMIN)
    returns (address)
    {
        return _taxWallet;
    }

    /// @notice Updates the tax amount.
    ///
    /// @dev Checks that the new tax amount is positive, then sets the tax amount.
    ///
    /// Requirements:
    /// - Must have TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newTaxAmount The new tax amount.
    /// @return Whether the tax amount was successfully set.
    function setTaxAmount(uint newTaxAmount)
    public
    onlyRole(Constants.TAX_ADMIN)
    returns (bool)
    {
        require (newTaxAmount >= 0, "TTM: tax amount must be positive or zero.");

        _taxAmount = newTaxAmount;

        return true;
    }

    /// @notice Gets the tax amount.
    ///
    /// Requirements:
    /// - Must have TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current tax amount.
    function getTaxAmount() 
    public
    view
    onlyRole(Constants.TAX_ADMIN)
    returns (uint)
    {
        return _taxAmount;
    }
}