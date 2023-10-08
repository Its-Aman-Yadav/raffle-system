// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLaneKeyHash;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address linkAddress;
    uint256 deployerKey;

    // Creating fake addresses using cheats
    address public PLAYER = makeAddr("player");
    uint256 public STARTING_USER_BALANCE = 10 ether;

    // Events
    event EnteredRaffle(address indexed player);

    // Modifiers
    modifier prankRaffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier prankRaffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Adding interval + 1 to the current block Timestamp to meet upkeep condition
        vm.warp(block.timestamp + interval + 1);
        // Adding new block to the current block number (to sound real 😀)
        vm.roll(block.number + 1);
        _;
    }

    // Setup Function
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLaneKeyHash,
            subscriptionId,
            callBackGasLimit,
            linkAddress,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    // Test functions
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    function testRevertRaffleWithLessEntraceFee() public {
        vm.prank(PLAYER);
        // vm.expectRevert();
        vm.expectRevert(Raffle.Raffle__EntraceFeeNotEnough.selector);

        // Sending less than the expected entrance fee
        raffle.enterRaffle{value: 0.005 ether}();
    }

    function testPlayerEnteringTheRaffle() public {
        vm.prank(PLAYER);

        // Pass the entrance fee while entering the Raffle
        raffle.enterRaffle{value: 0.02 ether}();

        address payable[] memory playerArray = raffle.getPlayers();
        assert(playerArray.length == 1);
        assert(playerArray[0] == PLAYER);
    }

    function testEmitEventOnEntrance() public {
        vm.prank(PLAYER);

        // Since we have only 1 indexed param - Only 1 true
        vm.expectEmit(true, false, false, false, address(raffle));

        // Emit the expected event to be tested
        emit EnteredRaffle(PLAYER);

        // At last, we make the function call where the actual event is emitted
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCannotEnterRaffleWhileChoosingWinner()
        public
        prankRaffleEntered
    {
        // Adding interval + 1 to the current block Timestamp to meet upkeep condition
        vm.warp(block.timestamp + interval + 1);

        // Adding new block to the current block number (to sound real 😀)
        vm.roll(block.number + 1);

        // This will change the status to ChoosingWinner
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);

        // We will again try to enter the raffle & it should fail
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ///////////////////
    //  checkUpKeep //
    //////////////////

    function testCheckUpkeepWithNoBalance() public {
        // ARRANGE - Setting Enough interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // ACT - Not setting balance for the contract (By not entering the Raffle)
        (bool upkeepRequired, ) = raffle.checkUpkeep("");

        // ASSERT - Checking if upkeep is required
        console.log("Raffle balance: ", address(raffle).balance);
        assertFalse(upkeepRequired);
    }

    function testCheckUpkeepWithRaffleNotOpen()
        public
        prankRaffleEnteredAndTimePassed
    {
        // ARRANGE - Enter raffle (prankRaffleEnteredAndTimePassed) & do performUpkeep
        raffle.performUpkeep("");

        // ACT - RaffleState has changed to ChoosingWinner, now checkUpkeep should fail
        (bool upkeepRequired, ) = raffle.checkUpkeep("");

        // ASSERT - Checking if upkeep is required
        assertFalse(upkeepRequired);
    }

    /////////////////////
    // performUpkeep  //
    ////////////////////

    function testPerformUpkeepOnlyRunsIfUpkeepIsNeeded()
        public
        prankRaffleEnteredAndTimePassed
    {
        // ARRANGE - prankRaffleEnteredAndTimePassed

        // ACT & ASSERT
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfUpkeepIsNotNeeded() public {
        // ARRANGE - All values will be 0 initially
        uint256 currentBalance = 0;
        uint256 raffleState = 0;
        uint256 numberOfPlayers = 0;

        // ACT, ASSERT - We are expecting the values to be returned as 0
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                raffleState,
                numberOfPlayers
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleState()
        public
        prankRaffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
        Raffle.RaffleState rfState = raffle.getRaffleState();
        console.log("Raffle State: ", uint256(rfState));
        assert(uint256(rfState) == 1);
    }

    function testPerformUpkeepEmitsEvent()
        public
        prankRaffleEnteredAndTimePassed
    {
        // ARRANGE - Start recording the logs by calling performUpkeep
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        console.log("Logged events: ", logEntries.length);

        /**
         * Asserrting the first event being emitted is RandomWordsRequested
         * The first topic is always the EVENT itself (The event declaration with types)
         * We will also assert the requestId being emitted is correct (2nd emitted parameter from the event)
         */
        assertEq(
            logEntries[0].topics[0],
            keccak256(
                "RandomWordsRequested(bytes32,uint256,uint256,uint64,uint16,uint32,uint32,address)"
            )
        );

        // Event RandomWordsRequested returns second param as requestId
        bytes32 requestId = logEntries[0].topics[2];
        console.log("Emitted RequestId: ", uint256(requestId));
        assert(requestId > 0);
        console.log("Emitted keyHash: ", uint256(logEntries[0].topics[1]));
    }

    ///////////////////////////
    // fulfillRandomWords   //
    //////////////////////////
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        // If we are on the local (ANVIL) chain, then proceed with this test
        _;
    }

    function testFulfillRandomWordsCallingOnlyAfterPerformUpkeep(
        uint256 randomRequestId
    ) public prankRaffleEntered skipFork {
        vm.expectRevert("nonexistent request");

        // Pretend to be ChainlinkVRF to call the fulfillRandomWords function
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsToChooseWinnerAndSendEthAndResetRaffle()
        public
        prankRaffleEnteredAndTimePassed
        skipFork
    {
        uint256 totalPlayers = 6;

        for (uint256 index = 1; index < totalPlayers; index++) {
            // To create new addresses on the fly, we will use address(1), address(2) & so on.
            // Cannot use address(0)
            // To create a new address, index should be casted to uint160
            address newPlayer = address(uint160(index));

            // hoax is equivalent to vm.prank(newPlayer);  vm.deal(newPlayer, STARTING_USER_BALANCE);
            hoax(newPlayer, STARTING_USER_BALANCE);

            raffle.enterRaffle{value: entranceFee}();
        }

        // Test all players have entered the raffle
        uint256 playersEntered = raffle.getPlayers().length;
        assertEq(playersEntered, totalPlayers);

        // Test the balance of raffle contract is more than 0
        uint256 raffleBalance = address(raffle).balance;
        console.log("Raffle Contract Balance: ", raffleBalance);
        assert(raffleBalance >= (playersEntered * entranceFee));

        // We need to get the correct requestId to get back the randomNumber
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[0].topics[2];
        console.log("RequestId: ", uint256(requestId));

        // Pretend to be ChainlinkVRF to get the random number
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        console.log("The winner is: ", raffle.getRecentWinner());
        // ASSERT
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getRecentWinner().balance > STARTING_USER_BALANCE);
        assert(address(raffle).balance == 0);
        assert(raffle.getPlayers().length == 0);
    }
}
