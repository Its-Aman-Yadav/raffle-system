// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// NatSpec (Natural Language Specification) is a system for documenting solidity code in a way that is easy for humans to understand.

/**
 * @title Sample Raffle Contract
 * @author Aman Yadav
 * @notice This contract is to create a sample raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    // Custom Errors
    error Raffle__EntraceFeeNotEnough();
    error Raffle__WinningTransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        RaffleState raffleState,
        uint256 numberOfPlayers
    );

    // Crating enum to maintain Lottery's current state (Internally mapped to integer values)
    enum RaffleState {
        Open, // 0
        ChoosingWinner // 1
    }
    RaffleState private s_raffleState;

    uint256 private immutable i_entranceFee;
    /** @dev Duration of the lottery in seconds */
    uint256 private immutable i_interval;
    /** @dev Parameters to be set for calling VRF */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLaneKeyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMBER_OF_WORDS = 1;
    uint256 private s_lastTimeStamp;

    // s_players is an array of payable addresses, because
    // we need to transfer the winning amount to the Raffle winner
    address payable[] private s_players;
    address private s_recentWinner;

    // Events
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLaneKeyHash,
        uint64 _subscriptionId,
        uint32 _callBackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        // VRFConsumerBaseV2 has a constructor with parameter, so we are declaring above
        s_raffleState = RaffleState.Open; // Opening Raffle for new entries
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLaneKeyHash = _gasLaneKeyHash;
        i_subscriptionId = _subscriptionId;
        i_callBackGasLimit = _callBackGasLimit;

        // Loading the block time during contract creation
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.Open) {
            revert Raffle__RaffleNotOpen();
        }

        if (msg.value < i_entranceFee) {
            revert Raffle__EntraceFeeNotEnough();
        }

        // Maintain the array for tracking all the players (addresses)
        s_players.push(payable(msg.sender));

        // Emitting the entered player's address (For logging)
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev checkUpkeep function is called by Chainlink Automation to see
     * if it's time to perform an upKeep.
     * Following conditions should be met in order to receive TRUE from the function call
     * 1. Specified time interval has passed from the Raffle starting time.
     * 2. The raffle is in OPEN state.
     * 3. The contract has balance (Players have joined).
     * 4. The Chainlink subscription is funded with LINKs (Implicit check).
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upKeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = (s_raffleState == RaffleState.Open);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);

        // Since we have already named the RETURN variables, explicit return statement is optional
        return (upKeepNeeded, "0x0");
    }

    // 1. Get a random number       2. Use random number to pick winner     3. Function be automatically called
    function performUpkeep(bytes calldata /* checkData */) external {
        // Check if upkeep is required
        (bool upkeepNeeded, ) = checkUpkeep("");

        // If the conditions are not matched, revert the function call with some additional data
        if (!upkeepNeeded) {
            // Provide more info with the error for easier debugging
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_raffleState,
                s_players.length
            );
        }

        // Raffle interval has met, so change RaffleState to ChoosingWinner
        s_raffleState = RaffleState.ChoosingWinner;

        // requestId will be used to match the request to a response in fulfillRandomWords
        //uint256 requestId =
        i_vrfCoordinator.requestRandomWords(
            i_gasLaneKeyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUMBER_OF_WORDS
        );
    }

    /*
        Override fulfillRandomWords (virtual) function is to perform action on the retrieved random number.
        This function will be INTERNALLY called from the rawFulfillRandomWords function, only if the 
        VRF-Coordinator is calling this rawFulfillRandomWords function (Refer to VRFConsumerBaseV2.sol file)
    */

    function fulfillRandomWords(
        uint256 /* _requestId */,
        uint256[] memory randomWords
    ) internal override {
        // rrandomWords is the array of Random numbers & we need only the first one
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;

        // Reset all the parameters to start a new Raffle
        s_players = new address payable[](0);
        s_raffleState = RaffleState.Open;
        s_lastTimeStamp = block.timestamp;

        // Emit the log to highlight the picked winner
        emit PickedWinner(winner);

        // Transfer the gathered amount to winner
        (bool callSuccess, ) = winner.call{value: address(this).balance}("");
        if (!callSuccess) {
            revert Raffle__WinningTransferFailed();
        }
    }

    /** Getter functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
