// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

error FundMe__NotOwner();

/** @title A sample Contract
 */
contract FundMe {
    // Type Declarations

    // State variables
    address private immutable i_owner;

    // Events

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    // Functions Order:
    //// constructor
    //// receive
    //// fallback
    //// external
    //// public
    //// internal
    //// private
    //// view / pure

    constructor(address priceFeed) {
        i_owner = msg.sender;
    }
}
