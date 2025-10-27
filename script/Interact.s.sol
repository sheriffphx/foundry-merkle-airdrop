//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract ClaimAirdrop is Script {
    bytes private SIGNATURE =
        hex"04209f8dfd0ef06724e83d623207ba8c33b6690e08772f8887a4eaf9a66b9182188938adea374fa542ad5ddde24bdc981f5e26a628e65fb425a68db8a938f6761c";

    error __MyScriptName_InvalidSignatureLength(); // Use a script-specific name

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        claimAirdrop(mostRecentlyDeployed);
    }

    function claimAirdrop(address airdropContractAddress) public {
        // Params for claim function
        address CLAIMING_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint256 CLAIMING_AMOUNT = 25 * 1e18;
        bytes32 PROOF_ONE = 0x5c22b3319c305aa1689a9386137ec820cfb5c1068b6699db995bec4f913b3421;
        bytes32 PROOF_TWO = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = PROOF_ONE;
        proof[1] = PROOF_TWO;
        // v, r, s components will be needed as well
        vm.startBroadcast();
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(airdropContractAddress).claim(CLAIMING_ADDRESS, CLAIMING_AMOUNT, proof, v, r, s);
        vm.stopBroadcast();
    }

    /**
     * @notice Splits a 65-byte concatenated signature (r, s, v) into its components.
     * @param sig The concatenated signature as bytes.
     * @return v The recovery identifier (1 byte).
     * @return r The r value of the signature (32 bytes).
     * @return s The s value of the signature (32 bytes).
     */
    function splitSignature(bytes memory sig) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        // Standard ECDSA signatures are 65 bytes long:
        // r (32 bytes) + s (32 bytes) + v (1 byte)
        if (sig.length != 65) {
            revert __MyScriptName_InvalidSignatureLength();
        }

        // Accessing bytes data in assembly requires careful memory management.
        // `sig` in assembly points to the length of the byte array.
        // The actual data starts 32 bytes after this pointer.
        assembly {
            // Load the first 32 bytes (r)
            r := mload(add(sig, 0x20)) // 0x20 is 32 in hexadecimal
            // Load the next 32 bytes (s)
            s := mload(add(sig, 0x40)) // 0x40 is 64 in hexadecimal
            // Load the last byte (v)
            // v is the first byte of the 32-byte word starting at offset 96 (0x60)
            v := byte(0, mload(add(sig, 0x60))) // 0x60 is 96 in hexadecimal
        }
        // Note: Further adjustment to 'v' might be needed depending on the signing library/scheme (see section below).
    }
}
