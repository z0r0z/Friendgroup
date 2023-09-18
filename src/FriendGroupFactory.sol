// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "./FriendGroup.sol";

contract FriendGroupFactory {
    event Deployed(
        FriendGroup indexed fg, uint256 indexed _thresh, address _admin, address _validator, address indexed _subject
    );

    FriendGroup[] public fgs;

    function deploy(uint256 _thresh, address _admin, address _validator, address _subject, bytes32 salt)
        public
        payable
        returns (FriendGroup fg)
    {
        fg = new FriendGroup{value: msg.value, salt: salt}(_thresh, _admin, _validator, _subject);
        fgs.push(fg);
        emit Deployed(fg, _thresh, _admin, _validator, _subject);
    }

    function determine(uint256 _thresh, address _admin, address _validator, address _subject, bytes32 salt)
        public
        view
        returns (address fg, bool deployed)
    {
        fg = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(FriendGroup).creationCode, abi.encode(_thresh, _admin, _validator, _subject)
                                )
                            )
                        )
                    )
                )
            )
        );
        assembly {
            deployed := extcodesize(fg)
        }
    }
}
