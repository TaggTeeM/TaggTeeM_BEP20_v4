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
    // tax settings
    address private _taxWallet = address(0);
    uint private _taxPercent = 1; // 1%

    // store the "non-"taxable status because default bool is false and we want taxing on for everyone as default
    mapping (address => bool) _nontaxableAddresses;

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
    function taxWallet()
    public
    view
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
    /// @param newTaxPercent The new tax amount.
    /// @return Whether the tax amount was successfully set.
    function setTaxPercent(uint newTaxPercent)
    public
    onlyRole(Constants.TAX_ADMIN)
    returns (bool)
    {
        require (newTaxPercent >= 0, "TTM: tax amount must be positive or zero.");

        _taxPercent = newTaxPercent;

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
    function taxPercent()
    public
    view
    returns (uint)
    {
        return _taxPercent;
    }

    /// @notice Checks if an address is taxable.
    ///
    /// @dev Returns the opposite of the "non-"taxable status because default bool is false and we want taxing on for everyone as default.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The account to check the taxable status for.
    /// @return Whether the account provided should be taxed.
    function isTaxable(address account)
    public
    view
    returns (bool)
    {
        // everyone is taxable unless otherwise specified
        return !_nontaxableAddresses[account];
    }

    /// @notice Sets the taxable status of the specified account.
    ///
    /// @dev Stores the "non-"taxable status because default bool is false and we want taxing on for everyone as default.
    ///
    /// Requirements:
    /// - Must have TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The new account to set the taxable status for.
    /// @param taxableStatus The new taxable status.
    /// @return Whether the taxable status was successfully set.
    function setTaxableStatus(address account, bool taxableStatus)
    public
    onlyRole(Constants.TAX_ADMIN)
    returns (bool)
    {
        // store the "non-"taxable status because default bool is false and we want taxing on for everyone as default
        _nontaxableAddresses[account] = !taxableStatus;

        return true;
    }
}