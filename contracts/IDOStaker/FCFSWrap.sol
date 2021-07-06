// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RaffleWrap.sol";

contract FCFSWrap is RaffleWrap {
    
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
        uint256 _price
    ) RaffleWrap (
        _stakerAddress,
        _nativeTokenAddress,
        _idoTokenAddress,
        _idoAmount,
        _price
    ) {

    }

    function initialize(uint256 time) external onlyOwner notInitialized {
        require(time >= block.timestamp, "IDO Can't Be in Past");

        regStarts = time;
        saleStarts = regStarts + saleStartsAfter;
        fcfsStarts = saleStarts + saleDuration;

        require(idoToken.balanceOf(address(this)) >= idoTokenSum, "Not Enough Tokens In Contract");

        emit Initialization(regStarts, saleStarts, fcfsStarts);
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
        IERC20Metadata tok = IERC20Metadata(tokenAddress);
        tok.transfer(to, tok.balanceOf(address(this)));
    }

    function isAfterFCFS() public view afterFCFSSale returns(bool) {
        return true;
    }

}