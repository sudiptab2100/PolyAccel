// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PolCoin is ERC20 {

    constructor () ERC20("Pol Coin", "PoCo") {
        _mint(msg.sender, 10000000 * (10 ** uint256(decimals())));
    }

}