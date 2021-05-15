// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
//import 'synthetix/contracts/interfaces/IAddressResolver.sol';
//import 'synthetix/contracts/interfaces/ISynthetix.sol';

/*
Gas opts to get down from 13.85
- Moved ticketValue into outside const
- Changed all uints to uint256s
Round 2:
- Take out constant math
- Moved buyTickets ticketCount declaration out of loop
- Set functions to external
- Consolidated buyTicket + _mint into just Buy Tickets
Round 3:
- remove lotteryprize mapping
- remove ticket owner mapping
Round 4:
- remove owner parameter from buyTickets
Round 5:
- remove return from buyTickets function
- remove owner variable declaration and just use msg.sender
- put functions back to external
Round 6:
- removed lottery start
*/

contract LotteryTicket is ERC721URIStorage, Ownable, VRFConsumerBase {
    //IAddressResolver public synthetixResolver;

    using Counters for Counters.Counter;
    Counters.Counter private _ticketIds;
    Counters.Counter private _lotteryIds;

    uint256 public constant ticketValue = 100000000000000000;

    struct _Lottery {
        uint256 end;
        uint256 tickets;
        uint256 id;
        uint256 prize;
        uint256[] winners;
    }

    // Managing Randomness
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    mapping (uint256 => uint256) pendingWithdrawals;

    mapping (uint256 => uint256) public lotteryEnd;
    mapping (uint256 => uint256) public lotteryTicketCount;
    mapping (uint256 => uint256) public ticketToLottery;
    mapping (uint256 => uint256) public ticketToPrize;
    mapping (uint256 => uint256[]) public lotteryWinners;

    event LotteryStarted(uint256 indexed lotteryId);
    event LotteryEnded(uint256 indexed lotteryId);

    constructor()
    ERC721("LotteryTicket", "TIX") payable
    VRFConsumerBase(
        0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
        0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
    )
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
        _createLottery();
    }

    /**
     * Purchases multiple tickets for the message sender.
     */
    function buyTickets(uint256 qty) external payable
    {
        require(msg.value == ticketValue*qty, "Ticket value must be correct.");

        // Verify current lottery or reset if necessary
        uint256 lotteryId = getOrResetLottery();

        uint256 ticketId;
        uint256 ticketCount;
        for(ticketCount=0; ticketCount<qty; ticketCount++) {

            // Mint our new lottery ticket
            _ticketIds.increment();
            ticketId = _ticketIds.current();
            _mint(msg.sender, ticketId);
            //_setTokenURI(ticketId, '{id}');

            // Save our required mappings
            // @TODO Save less of these
            lotteryTicketCount[lotteryId]++;
            ticketToLottery[ticketId] = lotteryId;
        }
    }

    /**
     * Claim my prize money
     */
    // @TODO update indexes when a token transfers
    function claimMyPrizes() external returns (uint) {
        uint256[] memory tickets = getMyTickets();
        require(tickets.length>0,"You do not own any tickets.");

        // Calculate and reset each of my ticket prizes
        uint256 amount = 0;
        uint256 i;
        uint256 ticketId;
        for(i=0;i<tickets.length;i++) {
            ticketId = tickets[i];
            amount += pendingWithdrawals[ticketId];
            pendingWithdrawals[ticketId] = 0;
        }

        // Transfer the winnings
        address payable winner = payable(msg.sender);
        winner.transfer(amount);
        return amount;
    }

    /**
     * Calculate how much money I won.
     */
    function getMyPrizes() external view returns (uint) {
        uint256[] memory tickets = getMyTickets();
        if(tickets.length < 1) {
            return 0;
        }

        uint256 amount = 0;
        uint256 i;
        uint256 ticketId;
        for(i=0;i<tickets.length;i++) {
            ticketId = tickets[i];
            amount += pendingWithdrawals[ticketId];
        }
        return amount;
    }

    function getCurrentLotteryId() view external returns (uint256) {
        uint256 lotteryId = _lotteryIds.current();
        return lotteryId;
    }

    function getCurrentLottery() view external returns (_Lottery memory) {
        uint256 lotteryId = _lotteryIds.current();
        _Lottery memory lottery = getLotteryById(lotteryId);
        return lottery;
    }

    function getLotteryById(uint256 id) view public returns (_Lottery memory) {
        _Lottery memory lottery = _Lottery(lotteryEnd[id], lotteryTicketCount[id], id, lotteryTicketCount[id] * ticketValue, lotteryWinners[id]);
        return lottery;
    }

    function getMyTickets() view public returns(uint256[] memory ownerTickets) {
        uint256 tokenCount = balanceOf(msg.sender);

        if (tokenCount == 0) {
            // Return an empty array
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

    function getTicketsByLotteryId(uint256 lotteryId) public view returns(uint256[] memory tickets) {
        uint256 ticketCount = lotteryTicketCount[lotteryId];

        if (ticketCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](ticketCount);
            uint256 totalTickets = _ticketIds.current();
            uint256 resultIndex = 0;

            uint256 ticketId;
            for (ticketId = 1; ticketId <= totalTickets; ticketId++) {
                if (ticketToLottery[ticketId] == lotteryId) {
                    result[resultIndex] = ticketId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    /**
     * Returns a valid lottery ID by creating a new one if necessary.
     */
    function getOrResetLottery() public returns (uint256) {
        uint256 lotteryId = _lotteryIds.current();

        if(lotteryEnd[lotteryId] > block.timestamp) {
            return lotteryId;
        } else {
            // Create a new lottery and end the old one
            uint256 newLotteryId = _createLottery();
            _endLottery(lotteryId);
            return newLotteryId;
        }
    }

    /**
     * Create a new lottery with predefined settings.
     */
    function _createLottery() private returns (uint256) {
        _lotteryIds.increment();
        uint256 lotteryId = _lotteryIds.current();
        lotteryEnd[lotteryId] = block.timestamp + 10 minutes;
        emit LotteryStarted(lotteryId);
        return lotteryId;
    }

    /**
     * End a lottery and calculate payouts.
     */
    function _endLottery(uint256 lotteryId) private {

        // Calculate prize pool
        // @TODO save some for operating costs
        uint256 totalPrize = lotteryTicketCount[lotteryId] * ticketValue;
        uint256 totalShares = 100;

        uint256[] memory tickets = getTicketsByLotteryId(lotteryId);
        if(tickets.length == 0) {
            // What to do for no tickets?
        } else if(tickets.length == 1) {
            // Give away 100%
            _awardPrize(lotteryId, tickets[0], _calculatePrize(totalPrize, 100, totalShares));
        } else if(tickets.length == 2) {
            // Give away 50/50?
            _awardPrize(lotteryId, tickets[0], _calculatePrize(totalPrize, 50, totalShares));
            _awardPrize(lotteryId, tickets[1], _calculatePrize(totalPrize, 50, totalShares));

        } else if(tickets.length == 3) {
            // Give away Normal splits
            _awardPrize(lotteryId, tickets[0], _calculatePrize(totalPrize, 50, totalShares));
            _awardPrize(lotteryId, tickets[1], _calculatePrize(totalPrize, 35, totalShares));
            _awardPrize(lotteryId, tickets[2], _calculatePrize(totalPrize, 10, totalShares));
        } else {
            // @TODO ADD THE RANDOMNESS FUNCTION
            // Give away Normal splits
            _awardPrize(lotteryId, tickets[0], _calculatePrize(totalPrize, 50, totalShares));
            _awardPrize(lotteryId, tickets[1], _calculatePrize(totalPrize, 35, totalShares));
            _awardPrize(lotteryId, tickets[2], _calculatePrize(totalPrize, 10, totalShares));
        }

        emit LotteryEnded(lotteryId);
    }

    function _awardPrize (uint256 lotteryId, uint256 ticketId, uint256 prizeAmount) private {
        ticketToPrize[ticketId] = prizeAmount;
        pendingWithdrawals[ticketId] += prizeAmount;
        lotteryWinners[lotteryId].push(ticketId);
    }

    function _calculatePrize(uint256 prize, uint256 share, uint256 totalShares) private pure returns (uint256) {
        uint256 payment = prize * share / totalShares;
        return payment;
    }


    /**
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }

    // Implement a withdraw function to avoid locking your LINK in the contract
    function withdrawLink() external {}
}



