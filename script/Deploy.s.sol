// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Script} from "@forge/Script.sol";
import {FriendGroup} from "src/FriendGroup.sol";

contract Deploy is Script {
    function run() public payable returns (FriendGroup fg) {
        vm.startBroadcast();
        fg;
        //fg = new FriendGroup(_threshold, address(0), _subject);
        vm.stopBroadcast();
    }
}
