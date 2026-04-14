// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TestV1} from "../src/FixedError.sol";

contract FixedVaultTest is Test {
    TestV1 vault;
    address user = makeAddr("user");

    function setUp() public {
        vault = new TestV1();
        vm.deal(user, 10 ether);
    }

    function test_Deposit() public {
        vm.prank(user);
        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(vault).balance;
        assertEq(userBalanceBefore, 10 ether);
        assertEq(contractBalanceBefore, 0 ether);

        vault.deposit{value: 1 ether}();
        
        uint256 userBalanceAfter = user.balance;
        uint256 contractBalanceAfter = address(vault).balance;

        assertEq(userBalanceAfter, 9 ether);
        assertEq(contractBalanceAfter, 1 ether);
    }

    function test_Withdraw() public {
        vm.startPrank(user);

        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(vault).balance;
        assertEq(userBalanceBefore, 10 ether);
        assertEq(contractBalanceBefore, 0 ether);

        vault.deposit{value: 1 ether}();

        uint256 userBalanceAfter = user.balance;
        uint256 contractBalanceAfter = address(vault).balance;

        assertEq(userBalanceAfter, 9 ether);
        assertEq(contractBalanceAfter, 1 ether);

        vault.withdraw(1 ether);

        uint256 userBalanceAfterWithdraw = user.balance;
        uint256 contractBalanceAfterWithdraw = address(vault).balance;

        assertEq(userBalanceAfterWithdraw, 10 ether);
        assertEq(contractBalanceAfterWithdraw, 0 ether);

        vm.stopPrank();
    }

    function test_WithdrawRevertsIfInsufficientBalance() public {
        vm.prank(user);

        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(vault).balance;
        assertEq(userBalanceBefore, 10 ether);
        assertEq(contractBalanceBefore, 0 ether);

        vm.expectRevert("Insufficient balance");
        vault.withdraw(1 ether);

        uint256 userBalanceAfterWithdraw = user.balance;
        uint256 contractBalanceAfterWithdraw = address(vault).balance;

        assertEq(userBalanceAfterWithdraw, 10 ether);
        assertEq(contractBalanceAfterWithdraw, 0 ether);

    }

    function test_CannotWithdrawMoreThanDeposited() public {
        vm.startPrank(user);

        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(vault).balance;
        assertEq(userBalanceBefore, 10 ether);
        assertEq(contractBalanceBefore, 0 ether);

        vault.deposit{value: 1 ether}();
        vm.expectRevert("Insufficient balance");
        vault.withdraw(2 ether);

        uint256 userBalanceAfterWithdraw = user.balance;
        uint256 contractBalanceAfterWithdraw = address(vault).balance;

        assertEq(userBalanceAfterWithdraw, 9 ether);
        vm.stopPrank();
    }
}
