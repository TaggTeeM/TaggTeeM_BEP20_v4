/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Depository {
    using SafeMath for uint;

    struct Lockbox {
        uint balance;
        uint lockboxId;
        uint releaseTime;
        address beneficiary;
        address creator;
    }

    // transactions tracker
    mapping (address => Lockbox[]) internal _lockboxDepository;
    mapping (address => uint) internal _restrictedCoinsTotal;

    function _addLockbox(address beneficiary, uint amount, uint duration)
    internal
    virtual
    returns (uint)
    {
        require (amount > 0, "TTM: New lockbox amounts must be greater than zero.");
        require (beneficiary != address(0), "TTM: Lockbox beneficiary invalid.");

        Lockbox memory newLockbox;

        newLockbox.balance = amount;
        newLockbox.lockboxId = _lockboxDepository[beneficiary].length;
        newLockbox.beneficiary = beneficiary;
        newLockbox.releaseTime = block.timestamp.add(duration);
        newLockbox.creator = msg.sender;

        _lockboxDepository[beneficiary].push(newLockbox);

        _restrictedCoinsTotal[beneficiary] += amount;

        return _lockboxDepository[beneficiary].length - 1;
    }

    function _getLockboxList(address requester)
    internal
    view
    returns (Lockbox[] memory)
    {
        return _lockboxDepository[requester];
    }

    function _restrictedCoins(address requester)
    internal
    view
    virtual
    returns (uint)
    {
        return _restrictedCoinsTotal[requester];
    }

    function _withdrawLockbox(address requester, uint lockboxId, uint amount)
    internal
    returns (bool)
    {
        address beneficiary = _lockboxDepository[requester][lockboxId].beneficiary;

        require (requester == _lockboxDepository[requester][lockboxId].creator
            || requester == beneficiary, "TTM: Only the lockbox creator or the beneficiary can withdraw from this lockbox.");

        return _withdrawLockbox(beneficiary, lockboxId, amount);
    }

    function _withdrawLockboxSpecial(address beneficiary, uint lockboxId, uint amount)
    internal
    returns (bool)
    {
        require (_lockboxDepository[beneficiary][lockboxId].balance >= amount, "TTM: Insufficient funds within lockbox for withdrawl.");
        require (block.timestamp >= _lockboxDepository[beneficiary][lockboxId].releaseTime, "TTM: Timelock has not expired on this lockbox.");

        _lockboxDepository[beneficiary][lockboxId].balance -= amount;
        _restrictedCoinsTotal[beneficiary] -= amount;

        return true;
    }
}
