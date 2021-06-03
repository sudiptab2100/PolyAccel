// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {

    constructor () ERC20("TestToken", "TeTo") {
        _mint(msg.sender, 10000000 * (10 ** uint256(decimals())));
    }

}