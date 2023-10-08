// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract InteractionTest is Script {
    CreateSubscription creatingSubscription;
    FundSubscription fundingSubscription;
    AddConsumer addingConsumer;
    HelperConfig helperConfig;
    Raffle raffle;

    address vrfCoordinator;
    uint64 subId;
    address linkAddress;
    uint256 deployerKey;

    function setUp() external {
        DeployRaffle deployedRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployedRaffle.run();
        creatingSubscription = new CreateSubscription();
        (, , vrfCoordinator, , subId, , linkAddress, deployerKey) = helperConfig
            .activeNetworkConfig();
        fundingSubscription = new FundSubscription();
        addingConsumer = new AddConsumer();
    }

    function testSubscriptionCannotBeCreatedWithInvalidCoordinatorAddress()
        public
    {
        vrfCoordinator = linkAddress;
        vm.expectRevert();
        creatingSubscription.createOwnSubscription(vrfCoordinator, deployerKey);
    }

    function testSubscriptionCreatedWithValidParameters() public {
        uint64 newSubId = 0;
        if (subId == newSubId) {
            newSubId = creatingSubscription.createOwnSubscription(
                vrfCoordinator,
                deployerKey
            );
        } else {
            revert();
        }
        assert(newSubId != subId);
    }

    function testCannotFundInvalidSubscription() public {
        // Call FundSubscription without creating a subscription
        vm.expectRevert(VRFCoordinatorV2Mock.InvalidSubscription.selector);
        fundingSubscription.fundSubscription(
            vrfCoordinator,
            subId,
            linkAddress,
            deployerKey
        );
    }

    function testOnlyVrfCoordinatorCanInvokeFundSubscription() public {
        vrfCoordinator = address(this);
        vm.expectRevert();
        fundingSubscription.fundSubscription(
            vrfCoordinator,
            subId,
            linkAddress,
            deployerKey
        );
    }

    function testConsumerCanBeAddedOnlyToValidSubscription() public {
        // Call AddConsumer without creating a subscription
        vm.expectRevert(VRFCoordinatorV2Mock.InvalidSubscription.selector);
        addingConsumer.addConsumer(
            vrfCoordinator,
            address(raffle),
            subId,
            deployerKey
        );
    }

    function testAnyConsumerCanBeAddedToTheSubscription() public {
        // ARRANGE
        subId = creatingSubscription.createOwnSubscription(
            vrfCoordinator,
            deployerKey
        );

        fundingSubscription.fundSubscription(
            vrfCoordinator,
            subId,
            linkAddress,
            deployerKey
        );

        // Passing invalid address to AddConsumer, but still consumer is created
        addingConsumer.addConsumer(
            vrfCoordinator,
            address(0),
            subId,
            deployerKey
        );
    }
}
