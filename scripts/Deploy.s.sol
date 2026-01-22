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

    GOVToken token = new GOVToken();
    DAOTimelock timelock;
    
    // Use a block to deploy and configure the timelock
    {
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new DAOTimelock(MIN_DELAY, proposers, executors, deployer);
    }

    DAOGovernor governor;
    // Use a block to deploy and initialize the governor proxy
    {
        DAOGovernor governorLogic = new DAOGovernor();
        bytes memory data = abi.encodeWithSelector(
            DAOGovernor.initialize.selector,
            token,
            timelock
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(governorLogic), data);
        governor = DAOGovernor(payable(address(proxy)));
    }

    Treasury treasury = new Treasury();

    // Roles block
    {
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        
        treasury.transferOwnership(address(timelock));
        
        // Finalize
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
    }

    vm.stopBroadcast();
}
}