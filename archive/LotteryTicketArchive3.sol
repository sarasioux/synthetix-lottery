// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";

contract LotteryTicket is ERC721, VRFConsumerBase, Ownable {

    // Managing Lotteries
    uint256 public ticketId;
    uint256 public ticketFloor;
    uint256 public prevTicketFloor;
    uint256 public end;
    bytes32 public pendingRandom;

    // Test field
    bool private fulfillOnNextRequest;

    // Managing Randomness
    bytes32 internal keyHash;
    uint256 internal fee;

    mapping (uint256 => uint256) public ticketToPrize;
    mapping (uint256 => uint256) public ticketFloorToRandom;
    mapping (bytes32 => uint256) private requestIdToTicketFloor;

    event LotteryEnded(bytes32 indexed requestId);
    event RandomReceived(bytes32 indexed requestId, uint256 indexed randomness, uint256 indexed floor);
    event WinnerChosen(uint256 indexed ticket, uint256 indexed prize);

    // @TODO MAKE VRF CONFIGURABLE BY NETWORK
    // https://docs.chain.link/docs/vrf-contracts/
    constructor() payable
    ERC721("LotteryTicket", "TIX")
    VRFConsumerBase(
        0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
        0x01BE23585060835E02B77ef475b0Cc51aA1e0709 // LINK Token
    )
    {
        // Pay for randomness
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)

        // @TODO compare storing this in a struct
        end = block.timestamp + 10 minutes;
    }

    /**
      * Purchases a single ticket, slightly less gas than the multiple purchase one
      */
    function buyTicket() external payable
    {
        require(msg.value == 1000000000000000, "Ticket value must be correct.");

        // @TODO remove for live
        if(fulfillOnNextRequest) {
            testFulfill();
        }
        if(pendingRandom > 0) {
            pickWinners(prevTicketFloor,ticketId,ticketFloorToRandom[prevTicketFloor]);
        }
        if(end < block.timestamp) {
            endLottery();
        }
        ticketId++;
        _safeMint(msg.sender, ticketId);
    }

    /**
     * Purchases multiple tickets for the message sender.
     */
    function buyTickets(uint256 qty) external payable {
        require(msg.value == 1000000000000000*qty, "Ticket value must be correct.");

        // Pay previous lottery winners
        if(pendingRandom > 0) {
            pickWinners(prevTicketFloor,ticketId,ticketFloorToRandom[prevTicketFloor]);
        }

        // End current lottery
        if(end < block.timestamp) {
            endLottery();
        }

        uint256 t;
        for(t=0; t<qty; t++) {
            ticketId++;
            _safeMint(msg.sender, ticketId);
        }
    }

    /**
     * End a lottery and start selection process.
     */
    function endLottery() public {
        // Pay previous lottery winners
        if(pendingRandom > 0) {
            pickWinners(prevTicketFloor,ticketId,ticketFloorToRandom[prevTicketFloor]);
        }

        require(end < block.timestamp, "Lottery must expire first.");

        // End the Lottery
        prevTicketFloor = ticketFloor;
        end = block.timestamp + 10 minutes;
        ticketFloor = ticketId;

        // Request our randomness
        bytes32 requestId = getRandomNumber(block.timestamp);
        requestIdToTicketFloor[requestId] = prevTicketFloor;

        emit LotteryEnded(requestId);
    }

    /**
     * Use random result to pick winners for the previous lottery.
     */
    function pickWinners(uint256 ticketStart, uint256 ticketEnd, uint256 randomness) private {
        // Get candidate tickets
        uint256[] memory tickets = new uint256[](ticketEnd - ticketStart);
        uint256 resultIndex = 0;
        uint256 i;
        for(i=ticketEnd;i>ticketStart;i--) {
            tickets[resultIndex] = i;
            resultIndex++;
        }

        // Calculate prize pool
        uint256 totalPrize = tickets.length * 1000000000000000;
        uint256 totalShares = 100;
        uint8[3] memory splits;
        if(tickets.length == 1) {
            splits[0] = 100;
        } else if(tickets.length == 2) {
            splits[0] = 50;
            splits[1] = 50;
        } else if(tickets.length >= 3) {
            splits = [50, 35, 15];
        }

        uint256 random;
        uint256 selection;
        uint256 prize;
        for(i=0; i<splits.length; i++) {
            if(splits[i] > 0) {
                // Pick the winner
                random = uint256(keccak256(abi.encode(randomness, i)));
                selection = random % (tickets.length - 1);
                prize = (totalPrize * splits[i]) / totalShares;
                ticketToPrize[tickets[selection]] = prize;

                // Delete the winner and rearrange the tickets so there's 1 less
                delete tickets[selection];
                tickets[selection] = tickets[tickets.length - 1];
                delete tickets[tickets.length - 1];
            }
        }

        // @TODO I don't think we need these
        // Track that we've already paid this floor out
        ticketFloorToRandom[prevTicketFloor] = 1;
        pendingRandom = 0;
    }

    /**
     * Claim my prizes
     */
    function claimMyPrizes() external returns (uint256 amount) {
        uint256[] memory tickets = getMyTickets();
        require(tickets.length>0,"You do not own any tickets.");

        // Calculate and reset each of my ticket prizes
        uint256 _ticket;
        for(uint256 i=0;i<tickets.length;i++) {
            _ticket = tickets[i];
            amount += ticketToPrize[_ticket];
            ticketToPrize[_ticket] = 0;
        }

        // Transfer the winnings
        address payable winner = payable(msg.sender);
        winner.transfer(amount);
        return amount;
    }

    /**
     * Get my tickets
     */
    function getMyTickets() view public returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(msg.sender);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalTickets = ticketId;
            uint256 resultIndex = 0;
            for (uint256 t = 1; t <= totalTickets; t++) {
                if (ownerOf(t) == msg.sender) {
                    result[resultIndex] = t;
                    resultIndex++;
                }
            }
            return result;
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
    // @TODO remove when going live
    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32) {
        fulfillOnNextRequest = true;
        return 0x81c58c267cf59603a0aadbd4783405b5bdddce7f6fe0831d707bfc3b2fc3580c;
    }

    /**
     * Processes random response, required by VRFCoordinator.
     */
    function fulfillRandomness(bytes32 _requestId, uint256 randomness) internal override {
        uint256  randomTicketFloor = requestIdToTicketFloor[_requestId];
        ticketFloorToRandom[randomTicketFloor] = randomness;
        pendingRandom = _requestId;
        emit RandomReceived(_requestId, randomness, randomTicketFloor);
    }

    // @TODO remove for live
    function testFulfill() private {
        fulfillRandomness(0x81c58c267cf59603a0aadbd4783405b5bdddce7f6fe0831d707bfc3b2fc3580c, 209384502983475092842983749823749238);
        fulfillOnNextRequest = false;
    }

    // Implement a withdraw function to avoid locking your LINK in the contract
    function withdrawLink() external {}

}



