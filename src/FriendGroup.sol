// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

contract FriendGroup {
    event Executed(address indexed to, uint256 val, bytes data, string note);
    event ThresholdUpdated(uint256 indexed threshold);

    error InvalidSignature();
    error InvalidThreshold();
    error InsufficientKeys();
    error Unauthorized();

    struct Sig {
        address usr;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    uint256 public threshold;
    address public immutable subject;
    bytes32 immutable domainSeparator = keccak256(
        abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("FriendGroup")),
            keccak256("1"),
            block.chainid,
            address(this)
        )
    );

    /// @dev Constructor...
    constructor(address _subject, uint256 _threshold) payable {
        if (_threshold > 100) revert InvalidThreshold();
        subject = _subject;
        threshold = _threshold;
    }

    /// @dev Execute Keyholder Ops...
    function execute(address to, uint256 val, bytes memory data, bool call, string calldata note, Sig[] calldata sigs)
        public
        payable
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encodePacked(
                        keccak256("Execute(address to,uint256 val,bytes data,bool call,string note"),
                        to,
                        val,
                        keccak256(data),
                        call,
                        note
                    )
                )
            )
        );

        Sig calldata sig;
        uint256 tally;
        address prev;

        for (uint256 i; i < sigs.length;) {
            sig = sigs[i];
            address usr = sig.usr;

            if (prev >= usr) revert InvalidSignature(); // No double vote.
            prev = usr;

            if (!isValidSignatureNow(usr, hash, sig.v, sig.r, sig.s)) {
                revert InvalidSignature();
            }

            unchecked {
                tally += FT.sharesBalance(subject, usr);
                ++i;
            }
        }

        unchecked {
            if (tally < threshold * FT.sharesSupply(subject) / 100) revert InsufficientKeys();
        }

        emit Executed(to, val, data, note);

        if (call) {
            assembly {
                let success := call(gas(), to, val, add(data, 0x20), mload(data), gas(), 0x00)
                returndatacopy(0x00, 0x00, returndatasize())
                if iszero(success) { revert(0x00, returndatasize()) }
                return(0x00, returndatasize())
            }
        } else {
            assembly {
                let success := delegatecall(gas(), to, add(data, 0x20), mload(data), gas(), 0x00)
                returndatacopy(0x00, 0x00, returndatasize())
                if iszero(success) { revert(0x00, returndatasize()) }
                return(0x00, returndatasize())
            }
        }
    }

    /// @dev Key Threshold Setting...
    function updateThreshold(uint256 _threshold) public payable {
        if (_threshold > 100) revert InvalidThreshold();
        if (msg.sender != address(this)) revert Unauthorized();
        threshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }

    /// @dev Receivers...
    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) public payable returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public payable returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        public
        payable
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    /// @dev eip-165...
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == this.supportsInterface.selector || interfaceId == this.onERC721Received.selector
            || interfaceId == this.onERC1155Received.selector || interfaceId == this.onERC1155BatchReceived.selector;
    }

    /// @dev eip-5267...
    function eip712Domain()
        public
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"0f"; // `0b01111`.
        (name, version) = ("FriendGroup", "1");
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = salt; // `bytes32(0)`.
        extensions = extensions; // `new uint256[](0)`.
    }
}

/// @dev FriendtechSharesV1 interface.
contract IFT {
    mapping(address => mapping(address => uint256)) public sharesBalance;
    mapping(address => uint256) public sharesSupply;
}

IFT constant FT = IFT(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);

/// @dev Signature checking modified from Solady (License: MIT).
/// (https://github.com/Vectorized/solady/blob/main/src/utils/SignatureCheckerLib.sol)
function isValidSignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s) view returns (bool isValid) {
    /// @solidity memory-safe-assembly
    assembly {
        // Clean the upper 96 bits of `signer` in case they are dirty.
        for { signer := shr(96, shl(96, signer)) } signer {} {
            let m := mload(0x40)
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff)) // `v`.
            mstore(0x40, r) // `r`.
            mstore(0x60, s) // `s`.
            let t :=
                staticcall(
                    gas(), // Amount of gas left for the transaction.
                    1, // Address of `ecrecover`.
                    0x00, // Start of input.
                    0x80, // Size of input.
                    0x01, // Start of output.
                    0x20 // Size of output.
                )
            // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
            if iszero(or(iszero(returndatasize()), xor(signer, mload(t)))) {
                isValid := 1
                mstore(0x60, 0) // Restore the zero slot.
                mstore(0x40, m) // Restore the free memory pointer.
                break
            }

            let f := shl(224, 0x1626ba7e)
            mstore(m, f) // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
            mstore(add(m, 0x04), hash)
            let d := add(m, 0x24)
            mstore(d, 0x40) // The offset of the `signature` in the calldata.
            mstore(add(m, 0x44), 65) // Length of the signature.
            mstore(add(m, 0x64), r) // `r`.
            mstore(add(m, 0x84), s) // `s`.
            mstore8(add(m, 0xa4), v) // `v`.
            // forgefmt: disable-next-item
            isValid := and(
                    // Whether the returndata is the magic value `0x1626ba7e` (left-aligned).
                    eq(mload(d), f),
                    // Whether the staticcall does not revert.
                    // This must be placed at the end of the `and` clause,
                    // as the arguments are evaluated from right to left.
                    staticcall(
                        gas(), // Remaining gas.
                        signer, // The `signer` address.
                        m, // Offset of calldata in memory.
                        0xa5, // Length of calldata in memory.
                        d, // Offset of returndata.
                        0x20 // Length of returndata to write.
                    )
                )
            mstore(0x60, 0) // Restore the zero slot.
            mstore(0x40, m) // Restore the free memory pointer.
            break
        }
    }
}
