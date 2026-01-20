// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Treasury is Ownable {

    event FundsWithdrawn(address indexed recipient, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function deposit() public payable {}

    function withdrawFunds(address payable recipient, uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        recipient.transfer(amount);
        emit FundsWithdrawn(recipient, amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
