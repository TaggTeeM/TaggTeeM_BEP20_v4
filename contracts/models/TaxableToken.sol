/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token TAXABLETOKEN contract
///
/// @author John Daugherty
///
contract TaxableToken is AccessControl {
    // Influencers For Change tax information
    address private _ifcTaxWallet = address(0);
    uint private _ifcTaxAmount = 1; // 1%

    function ifcTaxWallet()
    internal
    view
    returns (address)
    {
        return _ifcTaxWallet;
    }

    function ifcTaxAmount()
    internal
    view
    returns (uint)
    {
        return _ifcTaxAmount;
    }

    /// @notice Updates the IFC tax wallet address.
    ///
    /// @dev Checks that the new address is not 0, then sets the IFC tax wallet.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param taxWalletAddress The new IFC tax wallet address.
    /// @return Whether the IFC tax wallet address was successfully set.
    function setIfcTaxWallet(address taxWalletAddress)
    public
    onlyRole(Constants.IFC_TAX_ADMIN)
    returns (bool)
    {
        require (taxWalletAddress != address(0), "TTM: Attempt to set IFC tax wallet to address: 0");

        _ifcTaxWallet = taxWalletAddress;

        return true;
    }

    /// @notice Gets the IFC tax wallet address.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current IFC tax wallet address.
    function getIfcTaxWallet() 
    public
    view
    onlyRole(Constants.IFC_TAX_ADMIN)
    returns (address)
    {
        return _ifcTaxWallet;
    }

    /// @notice Updates the IFC tax amount.
    ///
    /// @dev Checks that the new tax amount is positive, then sets the IFC tax amount.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param taxAmount The new IFC tax amount.
    /// @return Whether the IFC tax amount was successfully set.
    function setIfcTaxAmount(uint taxAmount)
    public
    onlyRole(Constants.IFC_TAX_ADMIN)
    returns (bool)
    {
        require (taxAmount >= 0, "TTM: IFC tax amount must be positive or zero.");

        _ifcTaxAmount = taxAmount;

        return true;
    }

    /// @notice Gets the IFC tax amount.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current IFC tax amount.
    function getIfcTaxAmount() 
    public
    view
    onlyRole(Constants.IFC_TAX_ADMIN)
    returns (uint)
    {
        return _ifcTaxAmount;
    }
}