/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./models/Depository.sol";
import "./models/Nonvolumetric.sol";

///
/// @title TaggTeeM (TTM) token BEP20 contract
///
/// @author John Daugherty
///
contract TaggTeeM_BEP20_v4 is ERC20, ERC20Burnable, Pausable, AccessControl, ERC20Permit, ERC20Votes, Ownable, Depository, Nonvolumetric {
    using SafeMath for uint;

    // roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    bytes32 public constant NONVOLUMETRIC_ADMIN = keccak256("NONVOLUMETRIC_ADMIN");
    bytes32 public constant AIRDROPPER_ROLE = keccak256("AIRDROPPER_ROLE");
    bytes32 public constant RESTRICTION_ADMIN = keccak256("RESTRICTION_ADMIN");
    bytes32 public constant IFC_TAX_ADMIN = keccak256("IFC_TAX_ADMIN");
    bytes32 public constant SALES_HISTORY_ADMIN = keccak256("SALES_HISTORY_ADMIN");
    bytes32 public constant LOCKBOX_ADMIN = keccak256("LOCKBOX_ADMIN");

    /*
    // keep track of how much is in public supply
    uint private _totalPublicSupply;

    // whale settings
    uint private _whaleThreshold = 1; // 1%
    */

    // restrictions & sales settings
    uint private _presalesRestrictionTimeline = 8 * 30 * 24 * 60 * 60; // 8 months
    uint private _restrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _salesTrackerTimeline = 24 * 60 * 60; // 24 hours
    uint private _airdropRestrictionPercentage = 75; // 75%

    // founder coins
    uint private _founderRestrictionPercentage = 75; // 75%
    uint private _founderRestrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _founderBonusRestrictionPercentage = 1; // 1%

    /*
    // for nonvolumetric calculations
    uint private _nonvolumetricSettingsDivisor = 100; // to divide a, b, and k by
    int private _nonvolumetricA = 4000; 
    int private _nonvolumetricB = 600;
    int private _nonvolumetricK = 170;
    */

    // for keeping track of founder coins
    mapping (address => uint) private _founderCoinCounter;
    mapping (address => uint) private _founderCoinBalance;
    uint private _totalFounderCoinsIssued;

    // Influencers For Change tax information
    address private _ifcTaxWallet = address(0);
    uint private _ifcTaxAmount = 1; // 1%

    // restriction trackers
    mapping (address => uint) private _lastTransferDate;
    mapping (address => uint) private _transferTotals;

    constructor () ERC20("TaggTeeM", "TTM") ERC20Permit("TaggTeeM") {
        // grant token creator some basic permissions
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(MINTER_ROLE, _msgSender());
        grantRole(OWNER_ROLE, _msgSender());
        grantRole(PAUSER_ROLE, _msgSender());
        grantRole(SECURITY_ADMIN, _msgSender());

        // reassign admin role for all roles to SECURITY_ADMIN
        setRoleAdmin(OWNER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(FOUNDER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(PAUSER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(MINTER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(SECURITY_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(NONVOLUMETRIC_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(AIRDROPPER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(RESTRICTION_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(IFC_TAX_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(SALES_HISTORY_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(LOCKBOX_ADMIN, SECURITY_ADMIN);

        // mint 100b tokens at 10^decimals() decimals
        _mint(_msgSender(), 100000000000 * 10 ** decimals());
    }

    /// @notice Pauses coin trading.
    ///
    /// @dev Calls parent pause function.
    function pause() 
    public 
    onlyRole(PAUSER_ROLE) 
    {
        _pause();
    }

    /// @notice Unpauses coin trading.
    ///
    /// @dev Calls parent unpause function.
    function unpause() 
    public 
    onlyRole(PAUSER_ROLE) 
    {
        _unpause();
    }

    /// @notice Mints new coins.
    ///
    /// @dev Calls parent minting function.
    function mint(address to,  uint256 amount) 
    public 
    onlyRole(MINTER_ROLE) 
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

    /// @notice Performs any actions necessary before a coin transfer.
    ///
    /// @dev Calls parent function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of coin to send to the provided address.
    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @notice Performs any actions necessary after a coin transfer.
    ///
    /// @dev Calls parent function then records the transfer.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of coin to send to the provided address.
    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @notice Mints new coins.
    ///
    /// @dev Calls parent minting function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to transfer newly minted coins to.
    /// @param amount The amount of coin to send to the provided address.
    function _mint(address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    /// @notice Burns coins.
    ///
    /// @dev Calls parent burning function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to burn coins from.
    /// @param amount The amount of coin to burn.
    function _burn(address account, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }    

    function tradableBalanceOf(address account)
    public
    view
    returns (uint)
    {
        // add 24-hour sales tracker total to balance for whale/nonvolumetric checks
        return balanceOf(account).add(_transferTotals[account]).sub(restrictedCoins(account));
    }

    function tradableBalanceOf()
    public
    view
    returns (uint)
    {
        return tradableBalanceOf(_msgSender());
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
        uint lastMidnight = _salesTrackerTimeline == 0 ? block.timestamp : (block.timestamp / _salesTrackerTimeline) * _salesTrackerTimeline;
        uint tradableBalance = tradableBalanceOf(from);

        // reset sales counts every day at midnight
        if (_lastTransferDate[from] < lastMidnight)
            _transferTotals[from] = 0;

        // check if holder is a founder and is selling bonus coins (non-bonus coins are governed by active holder restrictions)
        if (_founderCoinBalance[from] > 0 && _founderBonusRestrictionPercentage > 0 && _founderCoinBalance[from] >= _founderCoinCounter[from].mul(_founderRestrictionPercentage.div(100)))
        {
            // if founder bonus coins, restrict sales per day
            require (amount.add(_transferTotals[from]).mul(100).div(_founderCoinCounter[from]) < _founderBonusRestrictionPercentage, "TTM: Trade exceeds daily limit for founder bonus coins.");

            isFounderTransfer = true;
        } 
        else if (from != owner())
            // check for whale trade cap, ignoring caps for the owner
            require (amount < getNonvolumetricMaximum(tradableBalance), "TTM: Maximum daily trade cap reached for this wallet's staking tier.");

        // check that we're not trying to transfer restricted coins
        if (_restrictionTimeline > 0 && restrictedCoins(from) > 0)
            require (amount <= tradableBalance, "TTM: Attempt to transfer restricted coins.");

        // IFC tax
        if (_ifcTaxAmount > 0 && _ifcTaxWallet != address(0)) 
        {
            uint taxAmount = amount.mul(_ifcTaxAmount).div(100);

            super._transfer(from, _ifcTaxWallet, taxAmount);

            amount = amount.sub(taxAmount);
        }

        // do the transfer
        super._transfer(from, to, amount);

        // record founder coin transfer
        if (isFounderTransfer || _founderCoinBalance[from] > 0)
            _founderCoinBalance[from] = _founderCoinBalance[from] < amount ? 0 : _founderCoinBalance[from].sub(amount);
        
        // record the trade for this user
        if (amount != 0)
        {
            _lastTransferDate[from] = lastMidnight;
            _transferTotals[from] = _transferTotals[from].add(amount);
        }
    }

    /// @notice Transfers _value amount of coins to the provided address with appropriate holder restrictions.
    ///
    /// @dev First verifies transfer, then adds coins to the restricted list.
    ///
    /// Requirements:
    /// - Must have AIRDROPPER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to airdrop to.
    /// @param amount The amount of coin to send to the provided address.
    /// @return Whether the transfer was a success.
    function airdrop(address to, uint256 amount)
    public
    whenNotPaused
    onlyRole(AIRDROPPER_ROLE)
    returns (bool)
    {
        require(super.transfer(to, amount));

        // add to restricted list
        addLockbox(to, amount.mul(_airdropRestrictionPercentage).div(100), _restrictionTimeline);

        return true;
    }
    
    /// @notice Transfers amount of coins to the provided address with appropriate preslaes restrictions.
    ///
    /// @dev First verifies transfer, then adds coins to the restricted list.
    ///
    /// Requirements:
    /// - Must have AIDROPPER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to presales airdrop to.
    /// @param amount The amount of coin to send to the provided address.
    /// @return Whether the transfer was a success.
    function presalesAirdrop(address to, uint256 amount)
    public
    whenNotPaused
    onlyRole(AIRDROPPER_ROLE)
    returns (bool)
    {
        require(super.transfer(to, amount));

        // add to restricted list
        addLockbox(to, amount.mul(_airdropRestrictionPercentage).div(100), _presalesRestrictionTimeline);

        return true;
    }

    /// @notice Transfers _value amount of coins to the provided address with appropriate founder restrictions.
    ///
    /// @dev Verifies coin transfer, then adds coins to restriction list and total founder coin list.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to send founder coins to.
    /// @param amount The amount of coin to send to the proveded address.
    /// @return Whether the transfer was a success.
    function sendFounderCoins(address to, uint256 amount)
    public
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require(super.transfer(to, amount));

        // mark 75% of coins as founder coins and add to restricted list using the founder restriction timeline
        if (_founderRestrictionTimeline > 0)
            addLockbox(to, amount.mul(_founderRestrictionPercentage).div(100), _founderRestrictionTimeline);

        // keep track of founder coins
        _founderCoinCounter[to] += amount;
        _founderCoinBalance[to] += amount;

        _totalFounderCoinsIssued += amount;

        return true;
    }

    /// @notice Returns the total number of founder coins for the caller.
    ///
    /// @dev Pulls count from found coin counter mapping based on message sender.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return Total number of founder coins for the caller.
    function getFounderCoinCount()
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return getFounderCoinCount(_msgSender());
    }

    /// @notice Returns the total number of founder coins for the account specified.
    ///
    /// @dev Pulls count from found coin counter mapping based on provided account address.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The wallet address to find the founder coin count for.
    /// @return Total number of founder coins for the account.
    function getFounderCoinCount(address account)
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderCoinCounter[account];
    }

    /// @notice Returns the total number of founder coins issued.
    ///
    /// @dev Pulls count from found coin counter variable.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return Total number of founder coins.
    function getTotalFounderCoinsIssued()
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _totalFounderCoinsIssued;
    }




    /*
    /// @notice Checks if the amount provided exceeds the whale threshold.
    ///
    /// @dev If the whale threshold is set to 0, always return false, otherwise check total public supply.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param amount The amount of coin to check for whale threshold.
    /// @return Whether the amount exceeds the whale threshold.
    function isWhale(uint256 amount) 
    public 
    view 
    returns (bool) {
        require (_totalPublicSupply > 0, "TTM: Error checking whale status - total coin supply not set");
        
        // whaleThreshold of 0 turns off whales
        if (_whaleThreshold == 0)
            return false;
        else
            return amount.mul(100).div(_totalPublicSupply) > _whaleThreshold;
    }
    */






    /// @notice Checks if the balance of the address provided exceeds the whale threshold.
    ///
    /// @dev If the whale threshold is set to 0, always return false, otherwise check total public supply.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The balance of the address to check for whale threshold.
    /// @return Whether the balance of the address exceeds the whale threshold.
    function isWhale(address account) 
    public 
    view 
    returns (bool) {
        return super.isWhale(balanceOf(account));
    }




    /*
    /// @notice Updates the whale threshold.
    ///
    /// @dev Checks that the new threshold is between 0 and 100, then sets the whale threshold.
    ///
    /// Requirements:
    /// - Must have NONVOLUMETRIC_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param whaleThreshold The new whale threshold.
    /// @return Whether the whale threshold was successfully set.
    function setWhaleThreshold(uint whaleThreshold) 
    public
    onlyRole(NONVOLUMETRIC_ADMIN)
    returns (bool)
    {
        // require that requested threshold is >= 0 && <= 100 - 0 turns off whale checking
        require (whaleThreshold >= 0 && whaleThreshold <= 100, "TTM: Nonvolumetric threshold must be between 0% and 100%.");

        // update whale threshold
        _whaleThreshold = whaleThreshold;

        return true;
    }

    /// @notice Gets the current whale threshold.
    ///
    /// Requirements:
    /// - Must have NONVOLUMETRIC_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current whale threshold.
    function getWhaleThreshold() 
    public
    view
    onlyRole(NONVOLUMETRIC_ADMIN)
    returns (uint)
    {
        return _whaleThreshold;
    }
    */






    /// @notice Updates the active restriction timeline.
    ///
    /// @dev Checks that the new timeline is positive, then sets the restriction timeline.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param restrictionTimeline The new restriction timeline.
    /// @return Whether the restriction timeline was successfully set.
    function setRestrictionTimeline(uint restrictionTimeline) 
    public
    onlyRole(RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (restrictionTimeline >= 0, "TTM: Restriction timeline must be positive.");

        // update restriction timeline
        _restrictionTimeline = restrictionTimeline;

        return true;
    }

    /// @notice Gets the current active restriction timeline.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current restriction timeline.
    function getRestrictionTimeline() 
    public
    view
    onlyRole(RESTRICTION_ADMIN)
    returns (uint)
    {
        return _restrictionTimeline;
    }

    /// @notice Updates the presales restriction timeline.
    ///
    /// @dev Checks that the new timeline is positive, then sets the restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param restrictionTimeline The new presales restriction timeline.
    /// @return Whether the presales restriction timeline was successfully set.
    function setPresalesRestrictionTimeline(uint restrictionTimeline) 
    public
    onlyRole(RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (restrictionTimeline >= 0, "TTM: Presales restriction timeline must be positive.");

        // update restriction timeline
        _presalesRestrictionTimeline = restrictionTimeline;

        return true;
    }

    /// @notice Gets the current presales restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current presales restriction timeline.
    function getPresalesRestrictionTimeline() 
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _presalesRestrictionTimeline;
    }

    /// @notice Updates the founder restriction timeline.
    ///
    /// @dev Checks that the new timeline is positive, then sets the founder restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param founderRestrictionTimeline The new founder restriction timeline.
    /// @return Whether the founder restriction timeline was successfully set.
    function setFounderRestrictionTimeline(uint founderRestrictionTimeline) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (founderRestrictionTimeline >= 0, "TTM: Founder restriction timeline must be positive");

        // update restriction timeline
        _founderRestrictionTimeline = founderRestrictionTimeline;

        return true;
    }

    /// @notice Gets the current founder restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder restriction timeline.
    function getFounderRestrictionTimeline() 
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderRestrictionTimeline;
    }

    /// @notice Updates the founder restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the founder restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param founderRestrictionPercentage The new founder restriction percentage.
    /// @return Whether the founder restriction percentage was successfully set.
    function setFounderRestrictionPercentage(uint founderRestrictionPercentage) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (founderRestrictionPercentage >= 0 && founderRestrictionPercentage <= 100, "TTM: Founder restriction must be between 0% and 100%");

        // update restriction timeline
        _founderRestrictionPercentage = founderRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current founder restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder restriction percentage.
    function getFounderRestrictionPercentage() 
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderRestrictionPercentage;
    }

    /// @notice Updates the airdrop restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the airdrop restriction percentage.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param airdropRestrictionPercentage The new airdrop restriction percentage.
    /// @return Whether the airdrop restriction percentage was successfully set.
    function setAirdropRestrictionPercentage(uint airdropRestrictionPercentage) 
    public
    onlyRole(RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (airdropRestrictionPercentage >= 0 && airdropRestrictionPercentage <= 100, "TTM: Airdrop restriction must be between 0% and 100%");

        // update restriction percentage
        _airdropRestrictionPercentage = airdropRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current airdrop restriction percentage.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current airdrop restriction percentage.
    function getAirdropRestrictionPercentage() 
    public
    view
    onlyRole(RESTRICTION_ADMIN)
    returns (uint)
    {
        return _airdropRestrictionPercentage;
    }

    /// @notice Updates the founder bonus restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the founder bonus restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param founderBonusRestrictionPercentage The new founder bonus restriction percentage.
    /// @return Whether the founder bonus restriction percentage was successfully set.
    function setFounderBonusRestrictionPercentage(uint founderBonusRestrictionPercentage) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (founderBonusRestrictionPercentage >= 0 && founderBonusRestrictionPercentage <= 100, "TTM: Founder bonus restriction must be between 0% and 100%");

        // update restriction percentage
        _founderBonusRestrictionPercentage = founderBonusRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current founder bonus restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder bonus restriction percentage.
    function getFounderBonusRestrictionPercentage() 
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderBonusRestrictionPercentage;
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
    onlyRole(IFC_TAX_ADMIN)
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
    onlyRole(IFC_TAX_ADMIN)
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
    onlyRole(IFC_TAX_ADMIN)
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
    onlyRole(IFC_TAX_ADMIN)
    returns (uint)
    {
        return _ifcTaxAmount;
    }

    /// @notice Updates the default sales tracker timeline.
    ///
    /// @dev Checks that the new timeline amount is positive, then sets the default sales tracker timeline.
    ///
    /// Requirements:
    /// - Must have SALES_HISTORY_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param salesTrackerTimeline The new default sales tracker timeline.
    /// @return Whether the default sales tracker timeline was successfully set.
    function setSalesTrackerTimeline(uint salesTrackerTimeline)
    public
    onlyRole(SALES_HISTORY_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (salesTrackerTimeline >= 0, "TTM: Sales tracker timeline must be positive.");

        // update restriction timeline
        _salesTrackerTimeline = salesTrackerTimeline;

        return true;
    }

    /// @notice Gets the default sales tracker timeline.
    ///
    /// Requirements:
    /// - Must have SALES_HISTORY_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current default sales tracker timeline.
    function getSalesTrackerTimeline() 
    public
    view
    onlyRole(SALES_HISTORY_ADMIN)
    returns (uint)
    {
        return _salesTrackerTimeline;
    }







    /*
    /// @notice Updates the total public supply.
    ///
    /// @dev Checks that the new supply amount is positive and less than the total supply, then sets the total public supply.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param totalPublicSupply The new total public supply.
    /// @return Whether the total public supply was successfully set.
    function setTotalPublicSupply(uint totalPublicSupply)
    public
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require (totalPublicSupply >= 0, "TTM: Total public supply can't be negative.");
        require (totalPublicSupply <= totalSupply(), "TTM: Total public supply can't be greater than the total coin supply.");

        _totalPublicSupply = totalPublicSupply;

        return true;
    }
    */





    /// @notice Updates the total public supply.
    ///
    /// @dev Checks that the new supply amount is positive and less than the total supply, then sets the total public supply.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param totalPublicSupply The new total public supply.
    /// @return Whether the total public supply was successfully set.
    function setTotalPublicSupply(uint totalPublicSupply)
    public
    override
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require (totalPublicSupply <= totalSupply(), "TTM: Total public supply can't be greater than the total coin supply.");

        return super.setTotalPublicSupply(totalPublicSupply);
    }






    /*
    /// @notice Gets the total public supply.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current total public supply.
    function getTotalPublicSupply() 
    public
    view
    returns (uint)
    {
        return _totalPublicSupply;
    }

    /// @notice Updates the nonvolumetric parameters.
    ///
    /// @dev Checks that the settings divisor is positive, then sets the parameters.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param NonvolumetricSettingsDivisor The new settings divisor.
    /// @param AParameter The new A parameter.
    /// @param BParameter The new B parameter.
    /// @param KParameter The new K parameter.
    /// @return Whether the parameters were successfully set.
    function setNonvolumetricParameters (uint NonvolumetricSettingsDivisor, int AParameter, int BParameter, int KParameter)
    public
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require (NonvolumetricSettingsDivisor > 0, "TTM: Settings divisor must be greater than 0");

        _nonvolumetricSettingsDivisor = NonvolumetricSettingsDivisor;
        _nonvolumetricA = AParameter;
        _nonvolumetricB = BParameter;
        _nonvolumetricK = KParameter;

        return true;
    }

    /// @notice Gets all nonvolumetric parameters.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return All of the nonvolumetric parameters.
    function getNonvolumetricParameters() 
    public
    view
    onlyRole(OWNER_ROLE)
    returns (uint, int, int, int)
    {
        return (_nonvolumetricSettingsDivisor, _nonvolumetricA, _nonvolumetricB, _nonvolumetricK);
    }

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the provided address.
    ///
    /// @dev Calls the internal function to get the maximum nonrestricted coins.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the maximum for.
    /// @return The total number of unrestricted coins.
    function getNonvolumetricMaximumFor(address account) 
    internal
    view
    returns (uint) 
    {
        return _applyNonvolumetricAlgoTo(account);
    }
    */






    

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the caller.
    ///
    /// @dev Calls the internal function to get the maximum nonrestricted coins for the message sender.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The total number of unrestricted coins for the caller.
    function getNonvolumetricMaximum() 
    public 
    view
    returns (uint) 
    {
        return super.getNonvolumetricMaximum(tradableBalanceOf(_msgSender()));
    }

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the provided address.
    ///
    /// @dev Calls the internal function to get the maximum nonrestricted coins.
    ///
    /// Requirements:
    /// - Must have NONVOLUMETRIC_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the maximum for.
    /// @return The total number of unrestricted coins.
    function getNonvolumetricMaximum(address account) 
    public 
    view
    onlyRole(NONVOLUMETRIC_ADMIN)
    returns (uint) 
    {
        return super.getNonvolumetricMaximum(tradableBalanceOf(account));
    }





    /*
    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the provided address.
    ///
    /// @dev If the holder is a whale, applies the NonVolumetric algorithm to their current holdings (including restricted coins), and returns the
    /// @dev   number of restricted coins they currently have. For non-whales, the whole balance (no restrictions) is returned.
    /// @dev The current nonvolumetric algorithm is =>> "y = a * ln(x * k) + b"
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the maximum for.
    /// @return The total number of unrestricted coins.
    function _applyNonvolumetricAlgoTo(address account)
    internal
    view
    returns (uint)
    {
        // add 24-hour sales tracker total to balance for whale/nonvolumetric checks
        uint balance = balanceOf(account).add(_transferTotals[account]).sub(restrictedCoins(account));

        if (isWhale(balance))
            return Algorithms.LogarithmicAlgoNatural(balance, _nonvolumetricSettingsDivisor, _nonvolumetricA, _nonvolumetricB, _nonvolumetricK)  * 10 ** decimals();
        else
            return balance;
    }
    */








    /// @notice Adds a new lockbox on the caller's wallet and funds it.
    ///
    /// @dev Checks that the caller's wallet (minus restricted coins) has enough coin to fund the lockbox.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param amount The amount to fund the lockbox for.
    /// @param lockLengthSeconds The length of time the lockbox will be locked, in seconds.
    /// @return NewLockbox The new lockbox details.
    function addLockbox(uint amount, uint lockLengthSeconds)
    public
    returns (Lockbox memory)
    {
        return addLockbox(_msgSender(), _msgSender(), amount, lockLengthSeconds);
    }

    /// @notice Adds a new lockbox on the beneficiary's wallet and funds it.
    ///
    /// @dev Checks that the beneficiary's wallet (minus restricted coins) has enough coin to fund the lockbox.
    ///
    /// Requirements:
    /// - Must have at least one of LOCKBOX_ADMIN, AIRDROPPER_ROLE, or OWNER_ROLE roles.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param beneficiary The address to make the lockbox on/for.
    /// @param amount The amount to fund the lockbox for.
    /// @param lockLengthSeconds The length of time the lockbox will be locked, in seconds.
    /// @return NewLockbox The new lockbox details.
    function addLockbox(address beneficiary, uint amount, uint lockLengthSeconds)
    public
    returns (Lockbox memory)
    {
        return addLockbox(_msgSender(), beneficiary, amount, lockLengthSeconds);
    }

    /// @notice Adds a new lockbox on the beneficiary's wallet and funds it.
    ///
    /// @dev Checks that the beneficiary's wallet (minus restricted coins) has enough coin to fund the lockbox.
    ///
    /// Requirements:
    /// - If requester is different than beneficiary, then must have at least one of LOCKBOX_ADMIN, AIRDROPPER_ROLE, or OWNER_ROLE roles.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param requester The address requestng the new lockbox.
    /// @param beneficiary The address to make the lockbox on/for.
    /// @param amount The amount to fund the lockbox for.
    /// @param lockLengthSeconds The length of time the lockbox will be locked, in seconds.
    /// @return The new lockbox details.
    function addLockbox(address requester, address beneficiary, uint amount, uint lockLengthSeconds)
    internal
    override
    returns (Lockbox memory)
    {
        require (balanceOf(beneficiary).sub(restrictedCoins(beneficiary)) >= amount, "TTM: Insufficient funds to create new lockbox.");

        return super.addLockbox(requester, beneficiary, amount, lockLengthSeconds);
    }
}