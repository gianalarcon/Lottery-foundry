// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A Raffle contract`
 * @author GMA
 * @notice This contract is for creating a sample raffle
 * @dev This contract implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnougthEthSent();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variable*/
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;

    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // Lottery Variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address payable s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed player);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_lastTimestamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_subscriptionId = _subscriptionId;
        i_gasLane = _gasLane;
        i_callbackGasLimit = _callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnougthEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() external {
        if ((block.timestamp - s_lastTimestamp) < i_interval) revert();
        s_raffleState = RaffleState.CALCULATING;
        uint256 request_id = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    // CEI:
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // 	require(	)

        // Effects
        uint256 indexWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit PickedWinner(winner);

        // Interactions (Other contratcs)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    /** Getters functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
