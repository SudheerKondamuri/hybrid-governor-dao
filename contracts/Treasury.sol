// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Treasury
 * @dev A simple vault contract that holds funds (ETH). 
 * The ownership will be transferred to the DAOTimelock so that only 
 * successful DAO proposals can authorize withdrawals.
 */
contract Treasury is Ownable {
    
    // Event emitted when funds are withdrawn
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    /**
     * @dev The constructor sets the initial owner to the deployer.
     * You must call transferOwnership(address(timelock)) after deployment.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Allows the contract to receive ETH.
     */
    receive() external payable {}

    /**
     * @notice Withdraws ETH from the treasury.
     * @dev Only the owner (which will be the Timelock) can call this function.
     * @param recipient The address to receive the funds.
     * @param amount The amount of ETH (in wei) to withdraw.
     */
    function withdrawFunds(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Treasury: Insufficient balance");
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Treasury: Transfer failed");

        emit FundsWithdrawn(recipient, amount);
    }

    /**
     * @notice Helper to check the current treasury balance.
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}