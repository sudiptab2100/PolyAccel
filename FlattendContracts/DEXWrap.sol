// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RaffleWrap.sol";

interface PairInterface {
    
    function sync() external;

}

interface FactoryInterface {
    
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);

}

interface RouterInterface {

    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
}

contract DEXWrap is RaffleWrap {

    uint256 public tokensToLiquidity;
    uint256 public softCapETH;
    uint256 public lpLockPeriod;
    uint256 public lpLockedTill;

    bool public isSoftLiquidityAdded;
    uint256 public liquidity = 0;

    RouterInterface public router;
    address public pairAddress;
    
    event Initialization(uint256 regStart, uint256 saleStart, uint256 fcfsStart);

    modifier afterFCFSSale() {
        uint256 x = 0;
        if(isFCFSNeeded()) {
            x = fcfsDuration;
        }
        require(isInitialized, "Not Initialized Yet");
        require(fcfsStarts + x <= block.timestamp, "FCFS: Sale Not Ended Yet");
        _;
    }

    constructor (
        address _stakerAddress,
        address _nativeTokenAddress,
        address _idoTokenAddress,
        uint256 _idoAmount,
        uint256 _price,
        uint256 _tokensToLiquidity,
        uint256 _softCapETH,
        uint256 _lpLockPeriod
    ) RaffleWrap (
        _stakerAddress,
        _nativeTokenAddress,
        _idoTokenAddress,
        _idoAmount,
        _price
    ) {
        tokensToLiquidity = _tokensToLiquidity;
        softCapETH = _softCapETH;
        lpLockPeriod = _lpLockPeriod;

        router = RouterInterface(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pairAddress = FactoryInterface(router.factory()).getPair(_idoTokenAddress, router.WETH());
        if(pairAddress == address(0)) {
            pairAddress = FactoryInterface(router.factory()).createPair(_idoTokenAddress, router.WETH());
        }
    }

    function initialize(uint256 time) external onlyOwner notInitialized {
        require(time >= block.timestamp, "IDO Can't Be in Past");

        regStarts = time;
        saleStarts = regStarts + saleStartsAfter;
        fcfsStarts = saleStarts + saleDuration;

        require(idoToken.balanceOf(address(this)) >= idoTokenSum + tokensToLiquidity, "Not Enough Tokens In Contract");

        emit Initialization(regStarts, saleStarts, fcfsStarts);
    }

    function _DEXAction() internal override {
        if(_isSoftCapReached() && !isSoftLiquidityAdded) {
            liquidity += _addLiquidity(tokensToLiquidity, softCapETH);
            lpLockedTill = block.timestamp + lpLockPeriod;
            isSoftLiquidityAdded = true;
        }
    }

    function _isSoftCapReached() internal view returns(bool res) {
        res = address(this).balance >= softCapETH;
    }

    function _addLiquidity(uint256 _tokenAmount, uint256 _ethAmount) internal returns(uint256 _liquidity) {

        idoToken.approve(address(router), _tokenAmount);

        (,, _liquidity) = router.addLiquidityETH{value : _ethAmount}(
            address(idoToken), 
            _tokenAmount, 
            0, 
            0, 
            address(this),
            block.timestamp + 360
        );
    }

    function isFCFSNeeded() public view returns(bool) {
        if(remainingIDOTokens > 0) return true;
        return false;
    }

    function swapPrice(uint256 amount) public view returns(uint256 price) {
        price = (amount * idoTotalPrice) / idoTokenSum;
    }

    function fcfsBuy(uint256 amount) public payable nonReentrant {
        uint256 price = swapPrice(amount);

        require(isFCFSNeeded(), "FCFS: Not Needed");
        require(getRegistrationStatus(msg.sender), "FCFS: You are not registered");
        require(block.timestamp >= saleStarts + saleDuration, "FCFS: Tier Sale not Ended Yet");
        require(amount != 0 && amount <= remainingIDOTokens, "FCFS: Invalid Amount");
        require(msg.value == price, "FCFS: Invalid Eth Value");

        idoToken.transfer(msg.sender, amount);
        remainingIDOTokens -= amount;
        _DEXAction();

        emit Purchase(msg.sender, amount, price);
    }

    function recoverEth(address to) external onlyOwner afterFCFSSale {
        (bool sent,) = address(to).call{value : address(this).balance}("");
        require(sent, 'Unable To Recover Eth');
    }

    function recoverERC20(
        address tokenAddress,
        address to
    ) external onlyOwner afterFCFSSale {
        if(tokenAddress == pairAddress) {
            require(block.timestamp >= lpLockedTill, "Liquidity Is Locked");
        }
        IERC20Metadata tok = IERC20Metadata(tokenAddress);
        tok.transfer(to, tok.balanceOf(address(this)));
    }

    function isAfterFCFS() public view afterFCFSSale returns(bool) {
        return true;
    }
    

    // Receive  External Eth
    event Received(address account, uint eth);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

}