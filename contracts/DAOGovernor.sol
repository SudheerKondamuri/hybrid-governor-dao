// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {GovernorTimelockControlUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

/**
 * @title DAOGovernor
 * @dev UUPS Upgradeable Governance contract with hybrid off-chain voting integration.
 */
contract DAOGovernor is
    Initializable,
    UUPSUpgradeable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable
{
    event OffchainVoteResultSubmitted(uint256 indexed proposalId, bool passed);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Replaces the constructor for upgradeable contracts.
     * @param _token The address of your GOVToken (must support IVotes).
     * @param _timelock The address of your DAOTimelock proxy.
     */
    function initialize(IVotes _token, TimelockControllerUpgradeable _timelock) public initializer {
        __Governor_init("MyDAOGovernor");
        __GovernorSettings_init(1, 45818, 0); // 1 block delay, ~1 week period, 0 threshold
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4); // 4% quorum
        __GovernorTimelockControl_init(_timelock);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Restricts who can upgrade the logic. Only the DAO itself can authorize an upgrade
     * through a successful governance proposal.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {}

    /**
     * @notice Hybrid Logic: Allows a successful DAO decision to attest to an off-chain result.
     * @param proposalId The ID of the active on-chain proposal.
     * @param passed Whether the off-chain vote was successful.
     */
    function submitOffchainVoteResult(uint256 proposalId, bool passed) 
        public 
        onlyGovernance 
    {
        require(state(proposalId) == ProposalState.Active, "DAOGovernor: Proposal is not active");

        if (passed) {
            emit OffchainVoteResultSubmitted(proposalId, passed);
        }
    }

    // --- Required Overrides for Multiple Inheritance ---

    function votingDelay() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalThreshold() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId) public view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}