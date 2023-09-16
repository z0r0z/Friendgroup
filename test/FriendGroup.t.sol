// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {FriendGroup, IFT} from "../src/FriendGroup.sol";
import "@forge/Test.sol";

contract FriendGroupTest is Test {
    IFT constant ft = IFT(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);
    address constant usrA = 0x1C0Aa8cCD568d90d61659F060D1bFb1e6f855A20;
    address constant usrB = 0x54816abFF584f6d7aB627981ecEcD6c3371aAc05;

    FriendGroup fg;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("base"));
        fg = new FriendGroup(usrA, 2);
    }

    function testSharesBalance() public payable {
        assertEq(ft.sharesBalance(usrA, usrA), 2);
    }

    function testDeployFG() public payable {
        new FriendGroup(usrA, 2);
    }
}
