// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './../interfaces/IStaker.sol';
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract IDO is Ownable, ReentrancyGuard {

    IStaker public iStaker;
    IERC20Metadata public nativeToken; // The token staked
    IERC20Metadata public idoToken; // The token sale in iDO
    uint256 public idoAmount; // Amount of Tokens to be Sold
    uint256 public idoPrice; // Price of 1 Tokens in Wei

    // Time Stamps
    uint256 public constant unit = 1 hours; // use seconds for testing
    uint256 public constant lockDuration = 7 * 24 * unit;
    uint256 public constant regDuration = 48 * unit;
    uint256 public constant saleStartsAfter = regDuration + 24 * unit;
    uint256 public constant saleDuration = 12 * unit;
    uint256 public regStarts;
    uint256 public saleStarts;

    event Initialization(uint256 regStart, uint256 saleStart);
    event Registration(address indexed account, uint256 poolNo);
    event Purchase(address indexed, uint256 tokens, uint256 price);

    struct UserLog {
        bool isRegistered;
        uint256 registeredPool;
        bool purchased;
    }
    mapping(address => UserLog) public userlog;

    bool public isInitialized;

    struct PoolInfo {
        string name;
        uint256 minNativeToken; // min token required to particitate in the pool
        uint256 weight;
        uint256 participants;
    } 
    PoolInfo[] public pools;
    uint256 public totalWeight;

    modifier verifyPool(uint256 _poolNo) {
        require(1 <= _poolNo && _poolNo <= 5, "invalid Pool no");

        uint256 stakedAmount = iStaker.stakedBalance(msg.sender);
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
        uint256 _idoAmount,
        uint256 _price
    ) {
        
        iStaker = IStaker(_stakerAddress);
        nativeToken = IERC20Metadata(_nativeTokenAddress);
        idoToken = IERC20Metadata(_idoTokenAddress);
        idoAmount = _idoAmount;
        idoPrice = _price;

        uint256 dec = uint256(nativeToken.decimals());
        pools.push(PoolInfo("Null", 0, 0, 0));
        pools.push(PoolInfo("Knight", 100 * 10**dec, 2, 0));
        pools.push(PoolInfo("Bishop", 500 * 10**dec, 3, 0));
        pools.push(PoolInfo("Rook", 1000 * 10**dec, 4, 0));
        pools.push(PoolInfo("King", 2000 * 10**dec, 5, 0));
        pools.push(PoolInfo("Queen", 4000 * 10**dec, 6, 0));
        totalWeight = 20;

    }

    function initialize(uint256 time) external onlyOwner notInitialized {
        require(time >= block.timestamp, "IDO Can't Be in Past");
        regStarts = time;
        saleStarts = regStarts + saleStartsAfter;
        require(idoToken.balanceOf(address(this)) >= idoAmount, "Not Enough Tokens In Contract");

        emit Initialization(regStarts, saleStarts);
    }

    function register(uint256 _poolNo) 
    external 
    validRegistration 
    verifyPool(_poolNo)
    nonReentrant {
        userlog[msg.sender].isRegistered = true;
        userlog[msg.sender].registeredPool = _poolNo;
        pools[_poolNo].participants += 1;

        iStaker.lock(msg.sender, block.timestamp + lockDuration);

        emit Registration(msg.sender, _poolNo);
    }

    function getPoolNo(address account) external view returns(uint256) {
        return userlog[account].registeredPool;
    }

    function tokensAndPrice(uint256 _poolNo) public view returns(uint256, uint256) {

        PoolInfo storage pool = pools[_poolNo];

        if(_poolNo == 0 || pool.participants == 0) {
            return (0, 0);
        }
        uint256 dec = uint256(idoToken.decimals());
        uint256 tokenAmount = (idoAmount * pool.weight) / (totalWeight * pool.participants); // Token Amount per Participants
        uint256 price = (tokenAmount * idoPrice) / (10 ** dec);

        return (tokenAmount, price);
    }

    function buyNow() external 
    payable 
    validSale
    nonReentrant {
        UserLog storage usr = userlog[msg.sender];
        (uint256 amount, uint256 price) = tokensAndPrice(usr.registeredPool);
        require(price != 0 && amount != 0, "Values Can't Be Zero");
        require(price == msg.value, "Not Valid Eth Amount");

        usr.purchased = true;
        idoToken.transfer(msg.sender, amount);

        emit Purchase(msg.sender, amount, price);
    }

    function recoverEth(address to) external onlyOwner {
        (bool sent,) = address(to).call{value : address(this).balance}("");
        require(sent, 'Unable To Recover Eth');
    }

    function recoverERC20(
        address tokenAddress, 
        address to
    ) external onlyOwner {
        IERC20Metadata tok = IERC20Metadata(tokenAddress);
        tok.transfer(to, tok.balanceOf(address(this)));
    }

}