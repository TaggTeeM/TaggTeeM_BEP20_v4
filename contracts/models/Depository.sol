/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token DEPOSITORY contract
///
/// @author John Daugherty
///
contract Depository is AccessControl {
    struct Lockbox {
        uint lockboxId;
        uint balance;
        uint releaseTime;
        address beneficiary;
        address creator;
    }

    // transactions tracker
    mapping (address => Lockbox[]) private _lockboxDepository;
    mapping (address => uint) private _restrictedCoinsTotal;

    // empty lockbox options
    bool private _removeEmptyLockboxes = true;

    // events
    event AddedLockbox(Lockbox newLockbox);
    event WithdrawLockbox(address beneficiary, uint lockboxId, uint amount);
    event CloseLockbox(address beneficiary, uint lockboxId, bool emptyLockboxRemoved);

    IERC20 private _parentContract;

    constructor()
    {
        _parentContract = IERC20(address(this));
    }

    /// @notice Sets the flag governing whether to remove lockboxes with 0 balances.
    ///
    /// @dev Sets the flag.
    ///
    /// Requirements:
    /// - Must have LOCKBOX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param removeEmptyLockboxes Whether to remove empty lockboxes.
    /// @return Whether the flag was set.
    function setRemoveEmptyLockboxes(bool removeEmptyLockboxes)
    public
    onlyRole(Constants.LOCKBOX_ADMIN)
    returns (bool)
    {
        _removeEmptyLockboxes = removeEmptyLockboxes;

        return _removeEmptyLockboxes;
    }

    /// @notice Gets the flag governing whether to remove lockboxes with 0 balances.
    ///
    /// @dev Returns the flag.
    ///
    /// Requirements:
    /// - Must have LOCKBOX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The value of the flag.
    function getRemoveEmptyLockboxes()
    public
    view
    onlyRole(Constants.LOCKBOX_ADMIN)
    returns (bool)
    {
        return _removeEmptyLockboxes;
    }

    /// @notice Gets the list of lockboxes in the caller's depository.
    ///
    /// @dev Returns list of lockboxes.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The list of lockboxes in the caller's depository.
    function getLockboxList()
    public
    view
    returns (Lockbox[] memory)
    {
        return getLockboxList(_msgSender());
    }

    /// @notice Gets the list of lockboxes in the account's depository.
    ///
    /// @dev Returns list of lockboxes.
    ///
    /// Requirements:
    /// - Must have LOCKBOX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The account to look for lockboxes on.
    /// @return The list of lockboxes in the account's depository.
    function getLockboxList(address account)
    public
    view
    virtual
    returns (Lockbox[] memory)
    {
        address msgSender = _msgSender();

        // only special roles can get the total restricted coin count for other people
        if (account != msgSender)
            require(hasRole(Constants.LOCKBOX_ADMIN, msgSender), "TTM: Insufficient permissions to get the complete lockbox list for other accounts.");

        return _lockboxDepository[account];
    }

    /// @notice Gets the total restricted coin count for the caller.
    ///
    /// @dev Returns total restricted coin count.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The caller's total restricted coin count.
    function restrictedCoins()
    public
    view
    returns (uint)
    {
        return restrictedCoins(_msgSender());
    }

    /// @notice Gets the total restricted coin count for the requested account.
    ///
    /// @dev Returns the total restricted coin count.
    ///
    /// Requirements:
    /// - If requester is different than beneficiary, then must have LOCKBOX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The account to get the total restricted coin count for.
    /// @return The account's total restricted coin count.
    function restrictedCoins(address account)
    public
    view
    virtual
    returns (uint)
    {
        return _restrictedCoinsTotal[account];
    }

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
    /// @dev Checks if the requester is the same as the beneficiary, does some sanity checking, creates a new lockbox, adds the lockbox to
    /// @dev   the depository, then updates the beneficiary's total restricted coin count, emits event.
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
    /// @param duration The length of time the lockbox will be locked, in seconds.
    /// @return The new lockbox details.
    function addLockbox(address requester, address beneficiary, uint amount, uint duration)
    internal
    virtual
    returns (Lockbox memory)
    {
        require (_parentContract.balanceOf(beneficiary) >= amount, "TTM: Insufficient balance to fund new lockbox.");

        // only special roles can make lockboxes for other people
        if (beneficiary != requester)
            require (hasRole(Constants.LOCKBOX_ADMIN, requester) 
                || hasRole(Constants.AIRDROPPER_ROLE, requester)
                || hasRole(Constants.OWNER_ROLE, requester), "TTM: Insufficient permissions to create lockboxes for other accounts.");

        require (amount > 0, "TTM: New lockbox amounts must be greater than zero.");
        require (beneficiary != address(0), "TTM: Lockbox beneficiary invalid.");

        // create and populate a new lockbox
        Lockbox memory newLockbox = Lockbox({
            balance: amount,
            lockboxId: _lockboxDepository[beneficiary].length,
            beneficiary: beneficiary,
            releaseTime: block.timestamp + duration,
            creator: requester
        });

        // add the lockbox to this beneficiary's depository
        _lockboxDepository[beneficiary].push(newLockbox);

        // keep track of this beneficiary's total restricted coin count
        _restrictedCoinsTotal[beneficiary] += amount;

        // event        
        emit AddedLockbox(newLockbox);

        return newLockbox;
    }

    /// @notice Withdraws funds from one of the caller's lockboxes.
    ///
    /// @dev Checks that the person requesting is the beneficiary, then calls the internal withdrawl function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param lockboxId The ID of the lockbox to withdraw from.
    /// @param amount The amount to withdraw from the lockbox.
    /// @return Whether the withdrawl was a success.
    function withdrawLockbox(uint lockboxId, uint amount)
    public
    virtual
    returns (bool)
    {
        address requester = _msgSender();
        address assignedBeneficiary = _lockboxDepository[requester][lockboxId].beneficiary;

        require (requester == assignedBeneficiary, "TTM: Only the lockbox beneficiary can withdraw from this lockbox.");

        return withdrawLockbox(requester, assignedBeneficiary, lockboxId, amount);
    }

    /// @notice Withdraws funds from one of the beneficiary's lockboxes.
    ///
    /// @dev Calls the internal withdrawl function.
    ///
    /// Requirements:
    /// - If requester is different than beneficiary, then must have at least one of LOCKBOX_ADMIN, AIRDROPPER_ROLE, or OWNER_ROLE roles.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param beneficiary The address to look for the lockbox.
    /// @param lockboxId The ID of the lockbox to withdraw from.
    /// @param amount The amount to withdraw from the lockbox.
    /// @return Whether the withdrawl was a success.
    function withdrawLockbox(address beneficiary, uint lockboxId, uint amount)
    public
    virtual
    returns (bool)
    {
        return withdrawLockbox(_msgSender(), beneficiary, lockboxId, amount);
    }

    /// @notice Withdraws funds from one of the beneficiary's lockboxes.
    ///
    /// @dev Checks if the requester is the same as the beneficiary, does some sanity checking, checks the timelock, removes funds from the lockbox,
    /// @dev   updates the beneficiary's total restricted coin count, removes empty lockbox (when applicable), emits event
    ///
    /// Requirements:
    /// - If requester is different than beneficiary, then must have at least one of LOCKBOX_ADMIN, AIRDROPPER_ROLE, or OWNER_ROLE roles.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param requester The address requestng the withdrawl.
    /// @param beneficiary The address to look for the lockbox.
    /// @param lockboxId The ID of the lockbox to withdraw from.
    /// @param amount The amount to withdraw from the lockbox.
    /// @return Whether the withdrawl was a success.
    function withdrawLockbox(address requester, address beneficiary, uint lockboxId, uint amount)
    internal
    returns (bool)
    {
        // only special roles can make lockboxes for other people
        if (requester != beneficiary)
            require (hasRole(Constants.LOCKBOX_ADMIN, requester) 
                || hasRole(Constants.AIRDROPPER_ROLE, requester)
                || hasRole(Constants.OWNER_ROLE, requester), "TTM: Unsufficient permissions to create lockboxes for other accounts.");

        // get the lockbox balance to memory so we can pay less gas
        uint lockboxBalance = _lockboxDepository[beneficiary][lockboxId].balance;

        require (lockboxBalance >= amount, "TTM: Insufficient funds within lockbox for withdrawl.");
        require (block.timestamp >= _lockboxDepository[beneficiary][lockboxId].releaseTime, "TTM: Timelock has not expired on this lockbox.");

        // figure out what the final balance is
        uint finalBalance = lockboxBalance - amount;

        // update lockbox and total restricted coin count
        _lockboxDepository[beneficiary][lockboxId].balance = finalBalance;
        _restrictedCoinsTotal[beneficiary] = _restrictedCoinsTotal[beneficiary] - amount;

        if (finalBalance <= 0)
        {
            if (_removeEmptyLockboxes)
            {
                // lockboxes can be unordered, so do easy removal here
                _lockboxDepository[beneficiary][lockboxId] = _lockboxDepository[beneficiary][_lockboxDepository[beneficiary].length - 1];

                _lockboxDepository[beneficiary].pop();
            }
    
            // emit event whether we're removing empty lockboxes or not so that we can indicate a lockbox is finished
            emit CloseLockbox(beneficiary, lockboxId, _removeEmptyLockboxes);
        }
        else
            emit WithdrawLockbox(beneficiary, lockboxId, amount);

        return true;
    }
}
