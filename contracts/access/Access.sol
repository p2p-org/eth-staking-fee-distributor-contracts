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
* @notice newOperator is the same as the old one
*/
error Access__SameOperator(address _operator);

/**
* @notice caller is not the operator
*/
error Access__CallerNotOperator(address _caller, address _operator);


abstract contract Access is Ownable {
    address private s_operator;

    event OperatorChanges(
        address indexed _previousOperator,
        address indexed _newOperator
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
    function operator() external view virtual returns (address) {
        return s_operator;
    }

    /**
     * @dev Throws if the sender is not the operator.
     */
    function _checkOperator() internal view virtual {
        if (s_operator != _msgSender()) {
            revert Access__CallerNotOperator(_msgSender(), s_operator);
        }
    }

    /**
     * @dev Transfers operator to a new account (`newOperator`).
     * Can only be called by the current owner.
     */
    function changeOperator(address _newOperator) external virtual onlyOwner {
        if (_newOperator == address(0)) {
            revert Access__ZeroNewOperator();
        }
        if (_newOperator == s_operator) {
            revert Access__SameOperator(_newOperator);
        }

        _changeOperator(_newOperator);
    }

    /**
     * @dev Transfers operator to a new account (`newOperator`).
     * Internal function without access restriction.
     */
    function _changeOperator(address _newOperator) internal virtual {
        address oldOperator = s_operator;
        s_operator = _newOperator;
        emit OperatorChanges(oldOperator, _newOperator);
    }

    /**
     * @dev Dismisses the old operator without setting a new one.
     * Can only be called by the current owner.
     */
    function dismissOperator() public virtual onlyOwner {
        _changeOperator(address(0));
    }
}
