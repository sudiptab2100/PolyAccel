// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStake {

    function stakedBalance(address account) external view returns (uint256);

    function unlockTime(address account) external view returns (uint256);

    function lock(address user, uint256 unlock_time) external;

}