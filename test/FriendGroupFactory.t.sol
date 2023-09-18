// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {FriendGroup, FriendGroupFactory} from "../src/FriendGroupFactory.sol";
import "@forge/Test.sol";

contract FriendGroupFactoryTest is Test {
    FriendGroupFactory factory;

    function setUp() public {
        factory = new FriendGroupFactory();
    }

    function testDeploy() public {
        uint256 initialCount = 0;
        uint256 _thresh = 51;
        address _admin = address(0x1);
        address _validator = address(0x2);
        address _subject = address(0x3);
        bytes32 salt = keccak256("salt");

        FriendGroup fg = factory.deploy(_thresh, _admin, _validator, _subject, salt);

        assert(address(factory.fgs(initialCount)) == address(fg));
    }

    function testDeployEvent() public {
        // This requires using the forge or dapp tools to capture logs and verify the Deployed event
        // Your test framework should provide ways to assert emitted events.
    }

    function testDetermineDeployed() public {
        uint256 _thresh = 51;
        address _admin = address(0x1);
        address _validator = address(0x2);
        address _subject = address(0x3);
        bytes32 salt = keccak256("salt");

        FriendGroup fg = factory.deploy(_thresh, _admin, _validator, _subject, salt);

        (address determinedFg, bool deployed) = factory.determine(_thresh, _admin, _validator, _subject, salt);
        assertEq(determinedFg, address(fg));
        assertTrue(deployed);
    }

    function testDetermineUndeployed() public {
        uint256 _thresh = 51;
        address _admin = address(0x1);
        address _validator = address(0x2);
        address _subject = address(0x3);
        bytes32 salt = keccak256("undeployedSalt");

        (address determinedFg, bool deployed) = factory.determine(_thresh, _admin, _validator, _subject, salt);
        // `determinedFg` should be a non-zero address, but `deployed` should be false
        assertTrue(determinedFg != address(0));
        assertFalse(deployed);
    }
}
