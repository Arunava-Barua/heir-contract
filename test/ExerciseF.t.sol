// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ExerciseF} from "../src/ExerciseF.sol";
contract ExerciseF_Test is Test {
    ExerciseF exerciseF;
    address heir = vm.addr(123);
    address owner = vm.addr(1234);
    uint startingBalance = 100 ether;
    function setUp() public {
        vm.startBroadcast(owner);
        exerciseF = new ExerciseF(heir);
        vm.deal(address(exerciseF), startingBalance);
        vm.stopBroadcast();
    }

    /*
     *@dev checking that all the storage variable are set correctly
     */
    function test_CheckValidStorageSetup() public view {
        address _owner = exerciseF.owner();
        uint32 _lastWithdraw = exerciseF.s_lastWithdraw();
        address _heir = exerciseF.s_heir();

        assertEq(_owner, owner);
        assertEq(_heir, heir);
        assertEq(_lastWithdraw, uint32(block.timestamp));
    }

    /*
     *@dev withdraw more than contract balance
     */
    function test_InvalidAmountWithdraw() public {
        vm.startBroadcast(owner);
        vm.expectRevert("Invalid withdraw amount");
        exerciseF.withdraw(1000 ether);
        vm.stopBroadcast();
    }

    /*
     *@dev withdraw after the window timeout i.e. withdraw after one month gap
     */
    function test_TimeoutWithdraw() public {
        vm.startBroadcast(owner);
        vm.warp(30 days + 2); // current block.timestamp is 1 and window ends at current block.timestamp + 30 days + 1 second
        vm.expectRevert("Withdraw Timeout");
        exerciseF.withdraw(10 ether);
        vm.stopBroadcast();
    }

    /*
     * @dev checking success withdraw by owner within withdraw window
     */
    function test_SuccessfulWithdraw() public {
        vm.startBroadcast(owner);
        vm.warp(10 days + block.timestamp);
        exerciseF.withdraw(10 ether);
        assertEq(owner.balance, 10 ether);
        assertEq(exerciseF.s_lastWithdraw(), 10 days + 1); // current block.timestap is 1 and we have moved timestamp with 10 days

        vm.stopBroadcast();
    }

    /*
     * @dev reseting timer with passing withdrAmount as 0
     */
    function test_ResetTimer() public {
        vm.startBroadcast(owner);
        vm.warp(block.timestamp + 10 days);
        exerciseF.withdraw(0);
        assertEq(exerciseF.s_lastWithdraw(), 1 + 10 days); // last block.timestamp = 1 and moved to next 10 days
        assertEq(address(exerciseF).balance, startingBalance);
        vm.stopBroadcast();
    }

    /*
     * @dev withdraw done by someone else instead of owner within withdraw window
     */
    function test_WithdrawNonOwner() public {
        vm.startBroadcast(vm.addr(1));
        vm.expectRevert();
        exerciseF.withdraw(10 ether);
        vm.stopBroadcast();
    }

    /*
     * @dev trying to updateHeir within withdraw window i.e. time left for owner to withdraw
     */
    function test_InvalidUpdateHeir() public {
        vm.startBroadcast(heir);
        vm.expectRevert("Withdraw is open for owner");
        exerciseF.updateHeir(vm.addr(789));
        vm.stopBroadcast();
    }

    /*
     * @dev listing condition which will successfully update heir address and make current heir as owner and reset timer
     */
    function test_SuccessfulUpdateHeir() public {
        vm.startBroadcast(heir);
        address newHeir = vm.addr(789);
        vm.warp(30 days + 2); // current block.timestamp is 1 and window ends at current block.timestamp + 30 days + 1 second
        exerciseF.updateHeir(newHeir);
        assertEq(exerciseF.owner(), heir);
        assertEq(exerciseF.s_heir(), newHeir);
        assertEq(exerciseF.s_lastWithdraw(), 30 days + 2);
        vm.stopBroadcast();
    }

    /*
     * @dev sending address(0) as newHeir
     */
    function test_InvalidNewHeir() public {
        vm.startBroadcast(heir);
        address newHeir = address(0);
        vm.warp(30 days + 2); // current block.timestamp is 1 and window ends at current block.timestamp + 30 days + 1 second
        vm.expectRevert("Invalid new heir address");
        exerciseF.updateHeir(newHeir);
        vm.stopBroadcast();
    }

    /*
     * @dev checking onlyHeir()
     */
    function test_NotHeirCall() public {
        vm.startBroadcast(vm.addr(789));
        // NOT_Heir.signature - 0xc9c0b698 : cast sig "NOT_Heir()"
        vm.expectRevert(0xc9c0b698);
        exerciseF.updateHeir(address(0));
        vm.stopBroadcast();
    }
}
