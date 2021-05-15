// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
//import 'synthetix/contracts/interfaces/IAddressResolver.sol';
//import 'synthetix/contracts/interfaces/ISynthetix.sol';

contract LotteryTicket is ERC721, VRFConsumerBase {
    //IAddressResolver public synthetixResolver;

    using Counters for Counters.Counter;
    Counters.Counter private _ticketIds;
    Counters.Counter private _lotteryIds;

    uint256 public end;

    // Managing Randomness
    //bytes32 internal keyHash;
    //uint256 internal fee;
    uint256 public randomResult;

    mapping (uint256 => uint256) public ticketToLottery;
    mapping (uint256 => uint256) public ticketToPrize;

    constructor()
    ERC721("LotteryTicket", "TIX") payable
    VRFConsumerBase(
        0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
        0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
    )
    {
        //keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        //fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)

        // Create a new lottery
        _lotteryIds.increment();
        end = block.timestamp + 10 minutes;
    }

    /**
     * Purchases multiple tickets for the message sender.
     */
    function buyTickets(uint256 qty) external payable
    {
        require(msg.value == 100000000000000000*qty, "Ticket value must be correct.");

        // Verify current lottery or reset if necessary
        if(end < block.timestamp) {
            end = block.timestamp + 10 minutes;
            _endLottery();
            _lotteryIds.increment();
        }

        uint256 lotteryId = _lotteryIds.current();

        uint256 ticketId;
        uint256 ticketCount;
        for(ticketCount=0; ticketCount<qty; ticketCount++) {

            // Mint our new lottery ticket
            _ticketIds.increment();
            ticketId = _ticketIds.current();
            _safeMint(msg.sender, ticketId);

            // Save our required mappings
            ticketToLottery[ticketId] = lotteryId;
        }
    }


    /**
     * Public function for resetting lottery without purchasing a ticket.
     */
    function resetLottery() external {
        if(end < block.timestamp) {
            // Create a new lottery and end the old one
            end = block.timestamp + 10 minutes;
            _endLottery();
            _lotteryIds.increment();
        }
    }

    /**
     * Claim my prize money
     */
    function claimMyPrizes() external returns (uint256 amount) {
        uint256[] memory tickets = getMyTickets();
        require(tickets.length>0,"You do not own any tickets.");

        // Calculate and reset each of my ticket prizes
        uint256 i;
        uint256 ticketId;
        for(i=0;i<tickets.length;i++) {
            ticketId = tickets[i];
            amount += ticketToPrize[ticketId];
            ticketToPrize[ticketId] = 0;
        }

        // Transfer the winnings
        address payable winner = payable(msg.sender);
        winner.transfer(amount);
        return amount;
    }

    /**
     * Calculate how much money I won.
     */
    function getMyPrizes() external view returns (uint256 amount) {
        uint256[] memory tickets = getMyTickets();
        if(tickets.length < 1) {
            return 0;
        }
        uint256 i;
        uint256 ticketId;
        for(i=0;i<tickets.length;i++) {
            ticketId = tickets[i];
            amount += ticketToPrize[ticketId];
        }
        return amount;
    }

    function getCurrentLotteryId() view external returns (uint256 lotteryId) {
        lotteryId =_lotteryIds.current();
        return lotteryId;
    }

    function getMyTickets() view public returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(msg.sender);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalTickets = _ticketIds.current();
            uint256 resultIndex = 0;
            uint256 ticketId;
            for (ticketId = 1; ticketId <= totalTickets; ticketId++) {
                if (ownerOf(ticketId) == msg.sender) {
                    result[resultIndex] = ticketId;
                    resultIndex++;
                }
            }
            return result;
        }
    }

    function getTicketsByLotteryId(uint256 getId) public view returns(uint256[] memory tickets) {
        uint256 totalTickets = _ticketIds.current();
        uint256[] memory result = new uint256[](totalTickets);
        uint256 resultIndex = 0;
        uint256 ticketId;
        for (ticketId = 1; ticketId <= totalTickets; ticketId++) {
            if (ticketToLottery[ticketId] == getId) {
                result[resultIndex] = ticketId;
                resultIndex++;
            }
        }
        return result;
    }

    /**
     * End a lottery and calculate payouts.
     */
    function _endLottery() private {

        uint256 lotteryId = _lotteryIds.current();

        // Calculate prize pool
        uint256[] memory tickets = getTicketsByLotteryId(lotteryId);
        uint256 totalPrize = tickets.length * 100000000000000000;
        uint256 totalShares = 100;

        if(tickets.length == 0) {
            // What to do for no tickets?
        } else if(tickets.length == 1) {
            // Give away 100%
            ticketToPrize[tickets[0]] = (totalPrize * 100) / totalShares;
        } else if(tickets.length == 2) {
            // Give away 50/50?
            ticketToPrize[tickets[0]] = (totalPrize * 50) / totalShares;
            ticketToPrize[tickets[1]] = (totalPrize * 50) / totalShares;

        } else if(tickets.length == 3) {
            // Give away Normal splits
            ticketToPrize[tickets[0]] = (totalPrize * 50) / totalShares;
            ticketToPrize[tickets[1]] = (totalPrize * 35) / totalShares;
            ticketToPrize[tickets[2]] = (totalPrize * 10) / totalShares;
        } else {
            // @TODO ADD THE RANDOMNESS FUNCTION
            // Give away Normal splits
            ticketToPrize[tickets[0]] = (totalPrize * 50) / totalShares;
            ticketToPrize[tickets[1]] = (totalPrize * 35) / totalShares;
            ticketToPrize[tickets[2]] = (totalPrize * 10) / totalShares;
        }
    }

    /**
     * Requests randomness from a user-provided seed
     */
    /*
    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }
    */

    /**
     * Callback function used by VRF Coordinator
     */

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }


    // Implement a withdraw function to avoid locking your LINK in the contract
    //function withdrawLink() external {}
}



