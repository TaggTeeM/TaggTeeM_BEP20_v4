/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./models/Depository.sol";
import "./models/Nonvolumetric.sol";
import "./models/PresaleRestrictionToken.sol";
import "./models/TaxableToken.sol";
import "./models/AirdroppedToken.sol";
import "./models/FounderToken.sol";
import "./models/SalesTracker.sol";
import "../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token BEP20 contract
///
/// @author John Daugherty
///
contract TaggTeeM_BEP20_v4 is ERC20, ERC20Burnable, ERC20Permit, Ownable, Depository, Nonvolumetric, TaxableToken, PresaleRestrictionToken, AirdroppedToken, FounderToken, SalesTracker {
    constructor () ERC20("TaggTeeM", "TTM") ERC20Permit("TaggTeeM") {
        // grant token creator some basic permissions
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(Constants.MINTER_ROLE, _msgSender());
        grantRole(Constants.OWNER_ROLE, _msgSender());
        grantRole(Constants.PAUSER_ROLE, _msgSender());
        grantRole(Constants.SECURITY_ADMIN, _msgSender());

        // reassign admin role for all roles to SECURITY_ADMIN
        setRoleAdmin(Constants.OWNER_ROLE, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.FOUNDER_ROLE, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.PAUSER_ROLE, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.MINTER_ROLE, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.SECURITY_ADMIN, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.NONVOLUMETRIC_ADMIN, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.AIRDROPPER_ROLE, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.RESTRICTION_ADMIN, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.IFC_TAX_ADMIN, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.SALES_HISTORY_ADMIN, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.LOCKBOX_ADMIN, Constants.SECURITY_ADMIN);
        setRoleAdmin(Constants.SWAPBACK_ADMIN, Constants.SECURITY_ADMIN);

        // mint 100b tokens at 10^decimals() decimals
        _mint(_msgSender(), 100000000000 * 10 ** decimals());

        // default total public supply is 25% of total supply
        setTotalPublicSupply((totalSupply() * 25) / 100);
    }

    /// @notice Pauses coin trading.
    ///
    /// @dev Calls parent pause function.
    function pause() 
    public 
    onlyRole(Constants.PAUSER_ROLE) 
    {
        _pause();
    }

    /// @notice Unpauses coin trading.
    ///
    /// @dev Calls parent unpause function.
    function unpause() 
    public 
    onlyRole(Constants.PAUSER_ROLE) 
    {
        _unpause();
    }

    /// @notice Mints new coins.
    ///
    /// @dev Calls parent minting function.
    function mint(address to,  uint256 amount) 
    public 
    onlyRole(Constants.MINTER_ROLE) 
    {
        _mint(to, amount);
    }

    /// @notice Sets the admin role for a particular role. The admin role will have permissions to assign people to the role.
    ///           The DEFAULT_ADMIN_ROLE is the admin role for all roles by default.
    ///
    /// @dev Calls parent function.
    ///
    /// Requirements:
    /// - Must have DEFAULT_ADMIN_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param role The role to set the admin for.
    /// @param adminRole The admin role for the role specified.
    function setRoleAdmin(bytes32 role, bytes32 adminRole) 
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRoleAdmin(role, adminRole);
    }

    /// @notice Gets an account's currently tradable balance.
    ///
    /// @dev The currently tradable balance is the total balance of the account less all restricted tokens.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the balance for.
    /// @return The tradable balance
    function balanceOf(address account) 
    public 
    view 
    override 
    returns (uint256) {
        return super.balanceOf(account) - restrictedCoins(account);
    }

    /// @notice Gets an account's total balance.
    ///
    /// @dev The current total balance is the total balance of the account including restricted tokens.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the balance for.
    /// @return The total balance
    function totalBalanceOf(address account)
    public
    view
    returns (uint)
    {
        return super.balanceOf(account);
    }

    /// @notice Performs appropriate limitation checks and cleanup when transferring coins.
    ///
    /// @dev First checks founder and nonvolumetric restrictions, then checks time restrictions before taking IFC
    ///   tax and then verifying the transfer. Then, founder coins are reduced as necessary.
    ///
    /// Requirements:
    /// - Founder coins must follow restriction requirements.
    /// - Whales must follow restriction requirements.
    /// - Must not be selling restricted coins.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of coin to send to the provided address.
    function _transfer(address from, address to, uint256 amount)
    override
    internal
    whenNotPaused
    {
        bool isFounderTransfer = false;
        uint tradableBalance = balanceOf(from);

        // reset sales counts every day at midnight
        uint lastMidnight = resetSalesTracker(from);

        // check if holder is a founder and is selling bonus coins (non-bonus coins are governed by active holder restrictions)
        if (founderCoinBalance(from) > 0 && founderBonusRestrictionPercentage() > 0 && founderCoinBalance(from) >= (founderCoinCounter(from) * founderRestrictionPercentage()) / 100)
        {
            // if founder bonus coins, restrict sales per day
            require (((amount + salesTrackerTotal(from)) * 100) / founderCoinCounter(from) < founderBonusRestrictionPercentage(), "TTM: Trade exceeds daily limit for founder bonus coins.");

            isFounderTransfer = true;
        } 
        else if (from != owner())
            // check for whale trade cap, ignoring caps for the owner
            require (amount < getNonvolumetricMaximum(tradableBalance), "TTM: Maximum daily trade cap reached for this wallet's staking tier.");

        // check that we're not trying to transfer restricted coins
        if ((restrictionTimeline() > 0 || presalesRestrictionTimeline() > 0) && restrictedCoins(from) > 0)
            require (amount <= tradableBalance, "TTM: Attempt to transfer restricted coins.");

        // IFC tax
        if (ifcTaxAmount() > 0 && ifcTaxWallet() != address(0)) 
        {
            uint taxAmount = (amount * ifcTaxAmount()) / 100;

            super._transfer(from, ifcTaxWallet(), taxAmount);

            amount -= taxAmount;
        }

        // do the transfer
        super._transfer(from, to, amount);

        // record founder coin transfer
        if (isFounderTransfer || founderCoinBalance(from) > 0)
            reduceFounderBalanceBy(from, amount);
        
        // record the trade for this user
        recordSale(from, amount, lastMidnight);
    }
}