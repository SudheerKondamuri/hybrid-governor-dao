// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GOVToken} from "../contracts/GOVToken.sol";
import {DAOTimelock} from "../contracts/DAOTimelock.sol";
import {DAOGovernor} from "../contracts/DAOGovernor.sol";
import {Treasury} from "../contracts/Treasury.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

contract DAOGovernorTest is Test {
    GOVToken token;
    DAOTimelock timelock;
    DAOGovernor governor;
    Treasury treasury;

    address public deployer = address(1);
    address public voter = address(2);
    address public secondVoter = address(3);
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18;

    function setUp() public {
        token = new GOVToken();
        // Give voter a massive amount of tokens to guarantee Quorum (4% of 1M = 40k)
        token.transfer(voter, 500000 * 10 ** 18);

        timelock = new DAOTimelock(
            3600,
            new address[](0),
            new address[](0),
            address(this)
        );

        DAOGovernor logic = new DAOGovernor();
        bytes memory data = abi.encodeWithSelector(
            DAOGovernor.initialize.selector,
            token,
            timelock
        );
        governor = DAOGovernor(
            payable(address(new ERC1967Proxy(address(logic), data)))
        );

        // Wiring
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        treasury = new Treasury();
        treasury.transferOwnership(address(timelock));

        // CRITICAL: Setup Voter Power BEFORE anything else
        vm.prank(voter);
        token.delegate(voter);

        // Roll forward several blocks so the delegation checkpoint is "past"
        vm.roll(block.number + 10);
    }

    function test_VotingPowerAndDelegation() public {
        vm.startPrank(voter);
        token.delegate(voter);
        vm.stopPrank();

        // Ensure delegation is recorded in a past block
        vm.roll(block.number + 2);

        uint256 votes = governor.getVotes(voter, block.number - 1);

        // FIX: Match the 500,000 CVT transferred in setUp
        assertEq(votes, 500000 * 10 ** 18);
    }

    function test_TokenNonces() public view {
        assertEq(token.nonces(voter), 0);
    }

    // --- Treasury Coverage ---

    function test_TreasuryDeposit() public {
        vm.deal(voter, 10 ether);
        vm.prank(voter);
        treasury.deposit{value: 5 ether}();
        assertEq(treasury.getBalance(), 5 ether);
    }

    function test_WithdrawFundsFailsForNonOwner() public {
        vm.deal(address(treasury), 1 ether);
        vm.prank(voter);
        vm.expectRevert(); // Likely OwnableUnauthorizedAccount
        treasury.withdrawFunds(payable(voter), 1 ether);
    }

    // --- Governor Coverage ---

    function test_ViewFunctionsCoverage() public view {
        assertEq(governor.votingDelay(), 1);
        assertEq(governor.votingPeriod(), 45818);
        assertEq(governor.proposalThreshold(), 0);
    }

    function test_FullProposalFlowAndExecution() public {
        vm.deal(address(treasury), 10 ether);

        address[] memory targets = new address[](1);
        targets[0] = address(treasury);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            Treasury.withdrawFunds.selector,
            payable(voter),
            1 ether
        );

        string memory description = "Withdrawal";

        // Propose
        vm.prank(voter);
        uint256 id = governor.propose(targets, values, calldatas, description);

        // Roll past voting delay (1 block)
        vm.roll(block.number + governor.votingDelay() + 1);

        // Vote
        vm.prank(voter);
        governor.castVote(id, 1);

        // Roll past voting period (45818 blocks)
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Verify state is Succeeded (4) not Defeated (3)
        assertEq(uint(governor.state(id)), 4);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + 3601);
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        assertEq(voter.balance, 1 ether);
    }

    function test_HybridOffchainSubmissionSuccess() public {
        // 1. Setup voting power and roll to finalize checkpoint
        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 5);

        // 2. Create a proposal with a real target (avoiding address(0) quirks)
        address[] memory targets = new address[](1);
        targets[0] = address(treasury); // Use treasury instead of 0x0
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(voter);
        uint256 id = governor.propose(
            targets,
            values,
            calldatas,
            "Hybrid Offchain Vote Test"
        );

        // 3. Roll past the Voting Delay to make the proposal Active
        vm.roll(block.number + governor.votingDelay() + 1);

        // Verify state is Active (1)
        assertEq(uint(governor.state(id)), 1);

        // 4. Submit result as the Timelock (the DAO executor)
        vm.prank(address(timelock));
        governor.submitOffchainVoteResult(id, true);
    }

    function test_UpgradeViaGovernance() public {
        // 1. Deploy new logic
        DAOGovernor newLogic = new DAOGovernor();

        // 2. Propose the upgrade
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(governor);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            governor.upgradeToAndCall.selector,
            address(newLogic),
            ""
        );

        vm.startPrank(voter);
        token.delegate(voter);
        vm.roll(block.number + 2);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Upgrade Governor"
        );

        vm.roll(block.number + governor.votingDelay() + 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Upgrade Governor"))
        );
        vm.warp(block.timestamp + 3601);
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Upgrade Governor"))
        );
        vm.stopPrank();
    }
}
