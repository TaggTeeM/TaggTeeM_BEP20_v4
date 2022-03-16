/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

contract ExpirableTransactionsTracker {
    struct TransactionsTracker {
        mapping (uint => uint) TxTimestamps;
        uint[] ActiveTimestamps;
    }

    // transactions tracker
    mapping (address => TransactionsTracker) private Transactions;
    mapping (address => bool) private ActiveTransactions;

    uint private _timelineOffset;

    constructor (uint timelineOffset) {
        _timelineOffset = timelineOffset;
    }

    function addTransaction(address from, uint amount, uint timelineOffset)
    public
    returns (bool)
    {
        uint currentTimestamp = block.timestamp;

        ActiveTransactions[from] = true;
        Transactions[from].ActiveTimestamps.push(currentTimestamp + timelineOffset);
        Transactions[from].TxTimestamps[currentTimestamp] += amount;

        return true;
    }

    function addTransaction(address from, uint amount)
    public
    returns (bool)
    {
        return addTransaction(from, amount, _timelineOffset);
    }

    function setTimelineOffset(uint timelineOffset)
    public
    returns (bool)
    {
        _timelineOffset = timelineOffset;

        return true;
    }

    function hasTransactions(address Holder)
    public
    view
    returns (bool)
    {
        return ActiveTransactions[Holder];
    }

    /*
    * Returns total active restricted coins and cleans out all expired holder restrictions.
    */
    function getUnexpiredTransactions(address _holder)
    public
    returns (uint)
    {
        uint restrictionCounter = 0;
        uint totalRestrictions = 0;

        for (restrictionCounter = Transactions[_holder].ActiveTimestamps.length; restrictionCounter >= 0; restrictionCounter--) {
            // check for expired restrictions
            if (Transactions[_holder].ActiveTimestamps[restrictionCounter] < block.timestamp) {
                // remove data
                //delete HolderRestrictions[_holder].ActiveTimestamps[restrictionCounter];

                // compact data
                //if (restrictionCounter < HolderRestrictions[_holder].ActiveTimestamps.length)
                Transactions[_holder].ActiveTimestamps[restrictionCounter] = Transactions[_holder].ActiveTimestamps[Transactions[_holder].ActiveTimestamps.length - 1];
            
                // reduce size of array by 1
                Transactions[_holder].ActiveTimestamps.pop();
            } else
                totalRestrictions += Transactions[_holder].TxTimestamps[Transactions[_holder].ActiveTimestamps[restrictionCounter]]; // restriction not expired, add to total
        }

        // no more restrictions exist for this holder, mark main array as such
        if (Transactions[_holder].ActiveTimestamps.length == 0)
            ActiveTransactions[_holder] = false;

        // send back the total restriction amount for this holder
        return totalRestrictions;
    }
}
