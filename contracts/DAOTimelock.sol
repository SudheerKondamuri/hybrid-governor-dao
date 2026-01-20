// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DAOTimelock is TimelockController {
    /**
     * @dev Constructor to set up the execution delay and roles.
     * @param minDelay The minimum time (in seconds) a proposal must wait after passing before execution.
     * @param proposers List of addresses that can propose actions (usually just the Governor).
     * @param executors List of addresses that can execute passed proposals (usually address(0) for everyone).
     * @param admin The address that sets up the initial roles (usually the deployer).
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}