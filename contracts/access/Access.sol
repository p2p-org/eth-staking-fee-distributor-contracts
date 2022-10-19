// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/access/Ownable.sol";

/**
* @notice it should not be possible to renounceOwnership
* to prevent losing control over the contract.
*/
error Access__CannotRenounceOwnership();

/**
* @notice newOperator is the zero address
*/
error Access__ZeroNewOperator();

/**
* @notice caller is not the operator
*/
error Access__CallerNotOperator(address _caller, address _operator);


abstract contract Access is Ownable {
    address private _operator;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    /**
     * @dev Throws if called by any account other than the operator.
     */
    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    /**
     * @dev Returns the current operator.
     */
    function operator() public view virtual returns (address) {
        return _operator;
    }

    /**
     * @dev Throws if the sender is not the operator.
     */
    function _checkOperator() internal view virtual {
        if (operator() != _msgSender()) {
            revert Access__CallerNotOperator(_msgSender(), operator());
        }
    }

    /**
     * @dev Transfers operator to a new account (`newOperator`).
     * Can only be called by the current owner.
     */
    function transferOperator(address newOperator) public virtual onlyOwner {
        if (newOperator == address(0)) {
            revert Access__ZeroNewOperator();
        }
        _transferOperator(newOperator);
    }

    /**
     * @dev Transfers operator to a new account (`newOperator`).
     * Internal function without access restriction.
     */
    function _transferOperator(address newOperator) internal virtual {
        address oldOperator = _operator;
        _operator = newOperator;
        emit OperatorTransferred(oldOperator, newOperator);
    }

    /**
     * @dev Dismisses the old operator without setting a new one.
     * Can only be called by the current owner.
     */
    function dismissOperator() public virtual onlyOwner {
        _transferOperator(address(0));
    }
}
