// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

/**
 * @dev To implement the subscription programmatically, we need to
 * 1. Create the Subscription
 * 2. Fund the Subscription
 * 3. Add the consumer
 */

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        // Better or de-constructed way of fetching NetworkConfig parameters from Helper Config
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLaneKeyHash,
            uint64 subscriptionId,
            uint32 callBackGasLimit,
            address linkAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        // If we don't have existing subscription, then will create one
        if (subscriptionId == 0) {
            CreateSubscription newSubscription = new CreateSubscription();
            subscriptionId = newSubscription.createOwnSubscription(
                vrfCoordinator,
                deployerKey
            );
        }

        // Fund Subscription
        FundSubscription fundingSubscription = new FundSubscription();
        fundingSubscription.fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkAddress,
            deployerKey
        );

        // Deploying Raffle contract
        vm.startBroadcast(deployerKey);
        Raffle deployedRaffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLaneKeyHash,
            subscriptionId,
            callBackGasLimit
        );
        vm.stopBroadcast();

        // Add consumer contract
        AddConsumer addingConsumer = new AddConsumer();
        addingConsumer.addConsumer(
            vrfCoordinator,
            address(deployedRaffle),
            subscriptionId,
            deployerKey
        );

        return (deployedRaffle, helperConfig);
    }
}
