// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GOVToken} from "../contracts/GOVToken.sol";
import {DAOTimelock} from "../contracts/DAOTimelock.sol";
import {DAOGovernor} from "../contracts/DAOGovernor.sol";
import {Treasury} from "../contracts/Treasury.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployDAO is Script {
    // Timelock configuration
    uint256 public constant MIN_DELAY = 3600; // 1 hour delay

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Governance Token
        GOVToken token = new GOVToken();

        // 2. Deploy Timelock
        // Initially, the deployer is the admin to set up roles. 
        // Proposers and executors are empty lists for now.
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        DAOTimelock timelock = new DAOTimelock(
            MIN_DELAY,
            proposers,
            executors,
            deployer
        );

        // 3. Deploy Governor Logic Contract
        DAOGovernor governorLogic = new DAOGovernor();

        // 4. Deploy Proxy for Governor
        // Encode the initialize call for the proxy
        bytes memory data = abi.encodeWithSelector(
            DAOGovernor.initialize.selector,
            IVotes(address(token)),
            TimelockControllerUpgradeable(payable(address(timelock)))
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(governorLogic), data);
        DAOGovernor governor = DAOGovernor(payable(address(proxy)));

        // 5. Deploy Treasury
        Treasury treasury = new Treasury();

        // --- 6. Set Up Roles (The "Wiring") ---

        // Grant roles on the Timelock to the Governor Proxy
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timelock.CANCELLER_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(cancellerRole, address(governor));
        
        // Allow anyone to execute a passed proposal (standard for many DAOs)
        timelock.grantRole(executorRole, address(0));

        // Transfer Treasury ownership to the Timelock
        treasury.transferOwnership(address(timelock));

        // FINALLY: Revoke the deployer's admin role on the Timelock
        // After this, only the DAO (via the Timelock itself) can change roles.
        timelock.revokeRole(adminRole, deployer);

        vm.stopBroadcast();
    }
}