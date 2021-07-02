// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Staker.sol';
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract IDO is Ownable, ReentrancyGuard {

    Staker public staker;
    IERC20Metadata public nativeToken; // The token staked
    IERC20Metadata public idoToken; // The token sale in iDO
    uint256 public idoTokenSum; // Amount of Tokens to be Sold
    uint256 public idoTotalPrice; // Price of 1 Tokens in Wei

    uint256 public totalPoolShares; // Total no of pool shares
    uint256 public remainingIDOTokens; // Tokens Not Sold Yet

    // Time Stamps
    uint256 public constant unit = 1 hours; // use seconds for testing
    uint256 public constant lockDuration = 7 * 24 * unit;
    uint256 public constant regDuration = 5 * 24 * unit;
    uint256 public constant saleStartsAfter = regDuration + 24 * unit;
    uint256 public constant saleDuration = 24 * unit;
    uint256 public constant fcfsDuration = 24 * unit;
    uint256 public regStarts;
    uint256 public saleStarts;
    uint256 public fcfsStarts;

    event Registration(address indexed account, uint256 poolNo);
    event Purchase(address indexed, uint256 tokens, uint256 price);

    struct UserLog {
        bool isRegistered;
        uint256 registeredPool;
        bool purchased;
    }
    mapping(address => UserLog) public userlog;
    address[] public participantList;

    bool public isInitialized;

    struct PoolInfo {
        string name;
        uint256 minNativeToken; // min token required to particitate in the pool
        uint256 weight;
        uint256 participants;
    } 
    PoolInfo[] public pools;

    modifier verifyPool(uint256 _poolNo) {
        require(1 <= _poolNo && _poolNo <= 5, "invalid Pool no");

        uint256 stakedAmount = staker.stakedBalance(msg.sender);
        require(pools[_poolNo].minNativeToken <= stakedAmount, "Can't Participate in the Pool");

        _;
    }

    modifier validRegistration() {
        uint256 t = block.timestamp;

        require(isInitialized, "Not Initialized Yet");
        require(!userlog[msg.sender].isRegistered, "Already registered");
        require(regStarts <= t && t <= regStarts + regDuration, "Not in Registration Period");
        _;
    }

    modifier validSale() {
        uint256 t = block.timestamp;

        require(isInitialized, "Not Initialized Yet");
        require(userlog[msg.sender].isRegistered, "Not registered");
        require(!userlog[msg.sender].purchased, "Already Purchased");
        require(saleStarts <= t && t <= saleStarts + saleDuration, "Not in Sale Period");
        _;
    }

    modifier notInitialized() {
        require(!isInitialized, "Already Initialized");
        _;
        isInitialized = true;
    }

    constructor (
        address _stakerAddress,
        address _nativeTokenAddress,
        address _idoTokenAddress,
        uint256 _idoTokenSum,
        uint256 _price
    ) {
        
        staker = Staker(_stakerAddress);
        nativeToken = IERC20Metadata(_nativeTokenAddress);
        idoToken = IERC20Metadata(_idoTokenAddress);
        idoTokenSum = _idoTokenSum;
        idoTotalPrice = _price;

        remainingIDOTokens = idoTokenSum;

        uint256 dec = uint256(nativeToken.decimals());
        pools.push(PoolInfo("Null", 0, 0, 0));
        pools.push(PoolInfo("Knight", 1000 * 10**dec, 1,  0));
        pools.push(PoolInfo("Bishop", 1500 * 10**dec, 4,  0));
        pools.push(PoolInfo("Rook",   3000 * 10**dec, 8,  0));
        pools.push(PoolInfo("King",   6000 * 10**dec, 16, 0));
        pools.push(PoolInfo("Queen",  9000 * 10**dec, 21, 0));

    }

    function register(uint256 _poolNo) 
    external 
    validRegistration 
    verifyPool(_poolNo)
    nonReentrant {
        staker.lock(msg.sender, saleStarts + saleDuration + lockDuration);
        _register(msg.sender, _poolNo);
    }

    function _register(address account, uint256 _poolNo) internal {
        userlog[account].isRegistered = true;
        userlog[account].registeredPool = _poolNo;
        pools[_poolNo].participants += 1;
        totalPoolShares += pools[_poolNo].weight;
        
        participantList.push(account);

        emit Registration(msg.sender, _poolNo);
    }

    function getPoolNo(address account) public view returns(uint256) {
        return userlog[account].registeredPool;
    }

    function noOfParticipants() public view returns(uint256) {
        return participantList.length;
    }

    function getRegistrationStatus(address account) public view returns(bool) {
        return userlog[account].isRegistered;
    }

    function tokensAndPriceByPoolNo(uint256 _poolNo) public view returns(uint256, uint256) {

        PoolInfo memory pool = pools[_poolNo];
        uint256 poolWeight = pool.weight;

        if(_poolNo == 0 || pool.participants == 0) {
            return (0, 0);
        }

        uint256 tokenAmount = (idoTokenSum * poolWeight) / totalPoolShares; // Token Amount per Participants
        uint256 price = (idoTotalPrice * poolWeight) / totalPoolShares; // Token Amount per Participants

        return (tokenAmount, price);
    }

    function allocationByAddress(address account) public view returns(uint256 tokens, uint256 price) {
        (tokens, price) = tokensAndPriceByPoolNo(userlog[account].registeredPool); // Normal Allocation
        (uint256 rTokens, uint256 rPrice) = _raffleAllocation(account); // Raffle Allocation

        tokens += rTokens;
        price += rPrice;
    }

    // This will be implemented in RaffleWrap
    function _raffleAllocation(address account) internal view virtual returns(uint256 tokens, uint256 price);

    // This will be implemented in DEXWrap
    function _DEXAction() internal virtual;

    function buyNow() external 
    payable 
    validSale
    nonReentrant {
        UserLog storage usr = userlog[msg.sender];
        (uint256 amount, uint256 price) = allocationByAddress(msg.sender);
        require(price != 0 && amount != 0, "Values Can't Be Zero");
        require(price == msg.value, "Not Valid Eth Amount");

        usr.purchased = true;
        remainingIDOTokens -= amount;
        idoToken.transfer(msg.sender, amount);

        _DEXAction();

        emit Purchase(msg.sender, amount, price);
    }

}