// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
import 'synthetix/contracts/interfaces/IAddressResolver.sol';
import 'synthetix/contracts/interfaces/IERC20.sol';

contract LotteryTicket is ERC721Burnable, VRFConsumerBase, Ownable {
    using SafeMath for uint256;

    // Lottery settings
    uint256 public constant ticketPrice = 5 * 1000000000000000000;
    uint256 public constant duration = 10 minutes;
    uint256 public constant lotteryFee = 10;  // 1%

    // Ticket NFT
    uint256 public ticketId;

    // Track id ranges for current and previous lottery
    uint256 public ticketFloor;
    uint256 public prevTicketFloor;

    // End date for current lottery
    uint256 public end;

    // Lottery fees collected
    uint256 public feesCollected;

    // Randomness management
    bytes32 internal keyHash;
    uint256 internal fee;

    // sUSD token interfaces
    IAddressResolver public synthetixResolver;
    address private synthAddress;

    // Track prizes
    mapping (uint256 => uint256) public ticketToPrize;

    // Events
    event LotteryEnded(uint256 ticketFloor, bytes32 requestId);
    event PrizePaid(uint256 indexed ticketId, uint256 indexed prize);
    event TicketBurned(uint256 indexed ticketId);

    /**
     * Start the lottery process with verified randomness and sUSD transactions.
     */
    constructor( address _vrfCoordinator, address _linkToken, address _resolver, bytes32 _keyHash) payable
    ERC721("LotteryTicket", "TIX")
    VRFConsumerBase(_vrfCoordinator, _linkToken) {
        // Manage sUSD
        synthetixResolver = IAddressResolver(_resolver);
        synthAddress = synthetixResolver.getAddress('ProxyERC20sUSD');
        require(synthAddress != address(0), 'sUSD is missing from Synthetix resolver');

        // Manage randomness and start lottery
        keyHash = _keyHash;
        fee = 0.1 * 10 ** 18;
        end = block.timestamp + duration;
    }

    /**
     * Purchases multiple tickets for the message sender.
     */
    function buyTickets(uint256 qty) external payable {
        // End current lottery
        if(end < block.timestamp) {
            endLottery();
        }

        // Transfer money
        uint256 amount = ticketPrice*qty;
        require(checkTokenBalance(msg.sender) >= amount, "Sender does not have the required balance to send.");
        IERC20(synthAddress).approve(address(this), amount);
        require(checkTokenAllowance(msg.sender, address(this)) >= amount, "Contract does not have permission to transfer tokens.");
        IERC20(synthAddress).transferFrom(msg.sender, address(this), amount);

        // Mint our tickets
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
        require(end < block.timestamp, "Lottery must expire first.");

        // End the Lottery
        prevTicketFloor = ticketFloor;
        end = block.timestamp + duration;
        ticketFloor = ticketId;

        // Request our randomness
        bytes32 requestId = getRandomNumber(block.timestamp);
        emit LotteryEnded(prevTicketFloor, requestId);
    }

    /**
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber(uint256 userProvidedSeed) internal returns (bytes32 _requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    /**
     * Processes random response, override function required by VRFCoordinator.
     */
    function fulfillRandomness(bytes32 _requestId, uint256 randomness) internal override {
        pickWinners(prevTicketFloor,ticketFloor,randomness);
    }

    /**
     * Use random result to pick winners for the previous lottery.
     */
    function pickWinners(uint256 ticketStart, uint256 ticketEnd, uint256 randomness) private returns (bool) {
        uint256 i;

        // Get candidate tickets
        uint256[] memory tickets = new uint256[](ticketEnd - ticketStart);
        uint256 resultIndex = 0;
        for(i=ticketEnd;i>ticketStart;i--) {
            tickets[resultIndex] = i;
            resultIndex++;
        }

        // Calculate prize pool and save some money for lottery fees
        uint256 totalPrize = tickets.length * ticketPrice;
        uint256 take = totalPrize.mul(lotteryFee).div(1000);
        feesCollected += take;
        totalPrize = totalPrize - take;

        // Adjust splits depending on entrants
        uint8[3] memory splits;
        if(tickets.length == 0) {
            return true;
        } else if(tickets.length == 1) {
            splits = [100, 0, 0];
        } else if(tickets.length == 2) {
            splits = [50, 50, 0];
        } else if(tickets.length >= 3) {
            splits = [50, 35, 15];
        }

        // Pick the winners
        uint256 selection;
        for(i=0; i<splits.length; i++) {
            if(splits[i] > 0) {
                // Select the winning ticket
                selection = uint256(keccak256(abi.encode(randomness, i))).mod(tickets.length.sub(1));
                ticketToPrize[tickets[selection]] = totalPrize.mul(splits[i]).div(100);
                emit PrizePaid(tickets[selection], ticketToPrize[tickets[selection]]);

                // Delete the winner and rearrange the tickets so there's 1 less so a ticket doesn't win twice
                if(tickets.length > 2 || (tickets.length == 2 && selection != tickets.length.sub(1))) {
                    delete tickets[selection];
                    tickets[selection] = tickets[tickets.length.sub(1)];
                    delete tickets[tickets.length.sub(1)];
                } else if(tickets.length == 2) {
                    delete tickets[selection];
                }
            }
        }

        return true;
    }

    /**
     * Claim my prizes. Once it's claimed we no longer have a record of the prize.
     */
    function claimMyPrizes() external {
        uint256 tokenCount = balanceOf(msg.sender);
        require(tokenCount>0,"You do not own any tickets.");
        uint256 amount;
        for (uint256 t = 1; t <= ticketId; t++) {
            if (_exists(t) && ownerOf(t) == msg.sender) {
                amount += ticketToPrize[t];
                ticketToPrize[t] = 0;
            }
        }

        // Transfer money
        IERC20(synthAddress).transferFrom(address(this), msg.sender, amount);
    }

    /**
     * Get my tickets helper function for front-end usability.
     * Concept borrowed from CryptoKitties.
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
                if (_exists(t) && ownerOf(t) == msg.sender) {
                    result[resultIndex] = t;
                    resultIndex++;
                }
            }
            return result;
        }
    }


    /**
     * Burn expired tickets so they don't show up in your UI or wallet anymore.
     * It's possible a user could burn tickets before they're paid out, I consider that their loss.
     * To protect against that change ticketFloor to prevTicketFloor below, but that will cause usability
     * issues on the front end. Would have to track if a lottery has been paid or not to avoid, increasing
     * overall contract storage costs.
     */
    function burnExpired() external {
        uint256[] memory tickets = getMyTickets();
        if(tickets.length > 0) {
            uint256 i;
            uint256 _ticketId;
            for(i=0; i<tickets.length; i++) {
                _ticketId = tickets[i];
                if(_ticketId <= ticketFloor && ticketToPrize[_ticketId] == 0) {
                    _burn(_ticketId);
                    emit TicketBurned(_ticketId);
                }
            }
        }
    }

    /**
     * Withdraw sUSD so we can convert to LINK and put it back.
     */
    function withdrawMoney() external onlyOwner {
        // Transfer money
        IERC20(synthAddress).transfer(msg.sender, feesCollected);
        feesCollected = 0;
    }

    /**
     * Check token balance of the user.
     */
    function checkTokenBalance(address account) public view returns (uint) {
        return IERC20(synthAddress).balanceOf(account);
    }

    /**
     * Check token allowance to the contract.
     */
    function checkTokenAllowance(address tokenOwner, address spender) public view returns (uint) {
        return IERC20(synthAddress).allowance(tokenOwner, spender);
    }
}
