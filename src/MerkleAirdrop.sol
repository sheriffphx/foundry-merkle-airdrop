//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MerkleAirdrop is EIP712 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping(address claimant => bool) private s_hasClaimed;

    // struct containing data to be signed
    struct AirdropClaim {
        address account;
        uint256 amount;
    }
    /**
     * @notice the stuct was hashed as a textto bytes32 format using keccak256
     */

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    event Claimed(address indexed account, uint256 amount);

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("Merkle Airdrop", "1.0.0") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }
    // Claim function and other Logic

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        // Check has claimed
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }
        // Verify the signature
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }
        // Check MerkleProof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }
        // Effect
        s_hasClaimed[account] = true;
        // Interactions
        emit Claimed(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }
    ///////////////////////
    // Getters
    /////////////////////

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    //////////////////
    // Helper
    /////////////////
    function _isValidSignature(address signer, bytes32 digest, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        // could also use SignatureChecker.isValidSignatureNow(signer, digest, signature)
        (
            address actualSigner,
            /*ECDSA.RecoverError recoverError*/
            ,
            /*bytes32 signatureLength*/
        ) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == signer);
    }
}

// forge install dmfxyz/murky
