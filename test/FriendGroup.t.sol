// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ft, FriendGroup} from "../src/FriendGroup.sol";
import "@forge/Test.sol";

contract FriendGroupTest is Test {
    address constant usrA = 0x1C0Aa8cCD568d90d61659F060D1bFb1e6f855A20;
    address constant usrB = 0x54816abFF584f6d7aB627981ecEcD6c3371aAc05;

    uint256 internal constant alicePk = 0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address internal constant alice = 0x503408564C50b43208529faEf9bdf9794c015d52;

    uint256 internal constant bobPk = 0xf8f8a2f43c8376ccb0871305060d7b27b0554d2cc72bccf41b2705608452f315;
    address internal constant bob = 0x001d3F1ef827552Ae1114027BD3ECF1f086bA0F9;

    FriendGroup fg;

    enum Op {
        call,
        delegatecall
    }

    struct Sig {
        address usr;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("base"));
        fg = new FriendGroup(51, usrA, address(0), usrA);
        vm.prank(0xdd9176eA3E7559D6B68b537eF555D3e89403f742);
        payable(alice).transfer(100 ether);
        vm.prank(alice);
        ft.buyShares{value: 0.5 ether}(usrA, 5);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testSharesBalance() public payable {
        assertEq(ft.sharesBalance(usrA, usrA), 2);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testInvalidThreshold() public payable {
        try new FriendGroup(0, address(0), address(0), usrA) {
            fail();
        } catch {
            // expected to revert
        }
        try new FriendGroup(101, address(0), address(0), usrA) {
            fail();
        } catch {
            // expected to revert
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testDeploy() public payable {
        new FriendGroup(51, address(0), address(0), usrA);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testExecute() public payable {
        FriendGroup.Sig[] memory sigs = new FriendGroup.Sig[](1);

        (uint8 v, bytes32 r, bytes32 s) = signExecution(alicePk, usrB, 0, "", Op.call);

        sigs[0] = FriendGroup.Sig({usr: alice, v: v, r: r, s: s});

        fg.execute(usrB, 0, "", FriendGroup.Op.call, sigs);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testFailInsufficientVote() public payable {
        FriendGroup.Sig[] memory sigs = new FriendGroup.Sig[](1);

        // Let's assume Alice has insufficient shares to meet the threshold.
        (uint8 v, bytes32 r, bytes32 s) = signExecution(alicePk, usrB, 0, "", Op.call);

        sigs[0] = FriendGroup.Sig({usr: alice, v: v, r: r, s: s});

        // This should fail as Alice's shares should be insufficient to meet the threshold.
        try fg.execute(usrB, 0, "", FriendGroup.Op.call, sigs) {
            fail();
        } catch (bytes memory) {
            // Expected to revert
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testUpdateAdmin() public payable {
        vm.prank(usrA);
        fg.updateAdmin(usrB);
        assertEq(fg.admin(), usrB);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testFailUnauthUpdateAdmin() public payable {
        vm.prank(usrB); // Switch to an unauthorized user
        fg.updateAdmin(usrB);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testUpdateThreshold() public payable {
        vm.prank(usrA);
        fg.updateThreshold(60);
        assertEq(fg.thresh(), 60);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testFailUpdateThreshold() public payable {
        vm.prank(usrB); // Switch to an unauthorized user
        fg.updateThreshold(60);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testMint() public payable {
        vm.prank(usrA);
        fg.mint(usrA, 100);
        assertEq(fg.balanceOf(usrA), 100);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testBurn() public payable {
        // Make sure usrA is authorized to burn tokens and has some tokens to burn
        vm.prank(usrA); // Switch to usrA
        fg.mint(usrA, 100); // Mint some tokens first
        vm.prank(usrA);
        fg.burn(usrA, 50); // Then burn
        assertEq(fg.balanceOf(usrA), 50); // Check if burn was successful
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function signExecution(uint256 pk, address to, uint256 val, bytes memory data, Op op)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        (v, r, s) = vm.sign(pk, getDigest(to, val, data, op, computeDomainSeparator(address(fg))));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function computeDomainSeparator(address addr) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("FriendGroup")),
                keccak256("1"),
                block.chainid,
                addr
            )
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    function getDigest(address to, uint256 val, bytes memory data, Op op, bytes32 domainSeparator)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        keccak256("Execute(address to,uint256 val,bytes data,uint8 op,uint256 nonce)"),
                        to,
                        val,
                        keccak256(data),
                        op,
                        0
                    )
                )
            )
        );
    }
}
