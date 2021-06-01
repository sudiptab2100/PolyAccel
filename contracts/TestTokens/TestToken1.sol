// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract TestToken1 is ERC20 {

    constructor () ERC20("Test Token 1", "TT1") {
        _mint(msg.sender, 10000000 * (10 ** uint256(decimals())));
    }

}