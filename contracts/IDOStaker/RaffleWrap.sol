// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
import "./IDO.sol";

abstract contract Random is VRFConsumerBase {

    bytes32 internal keyHash;
    uint256 internal fee;
    
    bytes32 public reqId;
    uint256 public randomResult;

    bool isGeneratedOnce;
    modifier once() {
        require(!isGeneratedOnce, "Already Generated Once");
        isGeneratedOnce = true;
        _;
    }

    constructor () VRFConsumerBase (
        0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
        0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
    ) {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 100000000000000000; // 0.1 LINK
    }

    /** 
     * Requests randomness from a user-provided seed
     */
    function _getRandomNumber(uint256 userProvidedSeed) internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        reqId = requestId;
        randomResult = randomness;
        _afterGeneration();
    }

    bool _isFulfilled = false;
    function isFulfilled() public view returns(bool) {
        return _isFulfilled;
    }

    // Generating Multiple Random Numbers From a Single One
    function _randomList(uint256 _from, uint256 _to, uint256 _size) internal view returns(uint256[] memory rands) {

        rands = new uint256[](_size);
        uint256 r = randomResult;
        uint256 len = _to - _from;
        
        require(len >= _size, "Invalid Size");

        uint256 i = 251;
        uint256 count = 0;

        while(count < _size) {
            uint256 rand = (r + i**2) % len + _from;
            bool exists = false;

            for(uint256 j = 0; j < count + 1; j++) {
                if (rand == rands[j]) {
                    exists = true;
                    break;
                }
            }

            if(!exists) {
                rands[count] = rand;
                count += 1;
            }

            i += 1;
        }
    }

    // This will execute after generation of Random Number
    function _afterGeneration() internal virtual;

}

abstract contract RaffleWrap is IDO, Random {

    uint256 public ticketsSold; // No of tickets sold
    mapping(uint256 => address) public ticketToOwner; // owner of a ticket
    mapping(address => uint256) public addressToTicketCount; // No Of Tickets Owned By an Address
    mapping(address => uint256[]) public addressToTicketsOwned; // Tickets That an address own
    mapping(address => bool) public hasWonRaffle;

    uint256 public constant RAFFLE_POOL = 2;
    uint256 public constant ticketPrice = 3 * 10 ** 18; // Price of a ticket(no. of tokens)

    modifier raffleParticipationPeriod() {
        require(regStarts <= block.timestamp, "Raffle: Participation Didn't Begin");
        require(regStarts + regDuration >= block.timestamp, "Raffle: Participation Ended");
        _;
    }

    modifier raffleResultPeriod() {
        require(regStarts + regDuration <= block.timestamp, "Raffle: Participation Didn't End");
        require(saleStarts >= block.timestamp, "Raffle: Out Of Time");
        _;
    }

    constructor (
        address _stakerAddress,
        address _nativeTokenAddress,
        address _idoTokenAddress,
        uint256 _idoAmount,
        uint256 _price
    ) IDO(
        _stakerAddress,
        _nativeTokenAddress,
        _idoTokenAddress,
        _idoAmount,
        _price
    ) {

    }

    
    // Buy Tickets
    function buyTickets(uint256 _noOfTickets) external raffleParticipationPeriod nonReentrant {
        require(isRaffleEligible(msg.sender), "Already Participated In IDO");
        uint256 nextTicket = ticketsSold;
        nativeToken.transferFrom(msg.sender, treasuryAddress, _noOfTickets * ticketPrice);

        for(uint256 i=0; i<_noOfTickets; i++) {
            ticketToOwner[nextTicket + i] = msg.sender;
            addressToTicketsOwned[msg.sender].push(nextTicket + i);
        }

        addressToTicketCount[msg.sender] += _noOfTickets;
        ticketsSold += _noOfTickets;
    }

    // Check if Account Is Eligible For Raffle Or Not
    function isRaffleEligible(address account) public view returns(bool) {
        return !getRegistrationStatus(account) || getPoolNo(account) != RAFFLE_POOL;
    }

    function _raffleAllocation(address account) internal view override returns(uint256 tokens, uint256 price) {
        tokens = price = 0;
        if(hasWonRaffle[account]) {
            (tokens, price) = tokensAndPriceByPoolNo(RAFFLE_POOL);
        }
    }

    // Generates The Random Winners
    function genRandom() external once raffleResultPeriod nonReentrant {
        uint256 seed = uint256(keccak256(abi.encodePacked(msg.sender)));
        _getRandomNumber(seed);
    }

    // Function Extended From Random Contract
    function _afterGeneration() internal override {
        _isFulfilled = true;
        _executeRaffle();
    }

    // Raffle Entry For Winners
    function _executeRaffle() internal {

        address[] memory list = _getWinners();
        for(uint256 i=0; i<list.length; i++) {
            address account = list[i];
            uint256 _poolNo = RAFFLE_POOL; // Raffle Entry Pool

            if(!hasWonRaffle[account] && getPoolNo(account) != _poolNo) {
                hasWonRaffle[account] = true;
                pools[_poolNo].participants++;
                totalPoolShares += pools[_poolNo].weight;
            }
        }
    }

    // Gets The Address Of The Winners
    function _getWinners() internal view returns(address[] memory list) {
        uint256 n = _noOfWinners(ticketsSold);
        list = new address[](n);
        uint256[] memory winners = _randomList(0, ticketsSold, n);

        for(uint256 i=0; i<n; i++) {
            address winner = ticketToOwner[winners[i]];
            list[i] = winner;
        }
    }

    function getWinners() external view returns(address[] memory) {
        require(isFulfilled(), "Winner Not Decided Yet");
        return _getWinners();
    }

    function getTicketsWon() external view returns(uint256[] memory) {
        require(isFulfilled(), "Winner Not Decided Yet");
        uint256 n = _noOfWinners(ticketsSold);
        return _randomList(0, ticketsSold, n);
    }

    // Calculates The Number Of Winners
    function _noOfWinners(uint256 _ticketsSold) internal pure returns(uint256) {
        return _ticketsSold / 100 + 1;
    }

}