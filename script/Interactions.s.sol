// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
// Ready-made contract from Cyfrin's repo
import {LinkToken} from "../test/mocks/LinkToken.sol";

/**
 * @dev To implement the subscription programmatically, we need to
 * 1. Create the Subscription
 * 2. Fund the Subscription
 * 3. Add the consumer
 */

contract CreateSubscription is Script {
    // Get NetworkConfig & its corresponding vrfCoordinator address
    function createSubscriptionConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();

        // Call createOwnSubscription function to get SubscriptionID
        return (createOwnSubscription(vrfCoordinator, deployerKey));
    }

    // Create VRF Subscription programatically
    function createOwnSubscription(
        address _vrfCoordinator,
        uint256 _deployerKey
    ) public returns (uint64) {
        console.log("Creating new subscription on ChainID: ", block.chainid);
        vm.startBroadcast(_deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Subscription created with ID: ", subId);
        return subId;
    }

    function run() public returns (uint64) {
        return (createSubscriptionConfig());
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 0.3 ether;

    function fundSubscriptionConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address linkAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subId, linkAddress, deployerKey);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint64 _subId,
        address _linkAddress,
        uint256 _deployerKey
    ) public {
        console.log("Funding the SubID: ", _subId);
        console.log("Using vrfCoordinator: ", _vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        // Anvil & Testnets have different ways to transfer LinkTokens
        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(_vrfCoordinator).fundSubscription(
                _subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployerKey);
            LinkToken(_linkAddress).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerConfig(address _raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        addConsumer(vrfCoordinator, _raffle, subId, deployerKey);
    }

    function addConsumer(
        address _vrfCoordinator,
        address _raffle,
        uint64 _subId,
        uint256 _deployerKey
    ) public {
        console.log("Adding new consumer contract: ", _raffle);
        console.log("Using vrfCoordinator: ", _vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(_deployerKey);
        VRFCoordinatorV2Mock(_vrfCoordinator).addConsumer(_subId, _raffle);
        vm.stopBroadcast();
    }

    function run() public {
        address raffle = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Needs correction
        addConsumerConfig(raffle);
    }
}
