//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MerkleAirdopTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;

    bytes32 merkleRoot = 0xf30d5b84fa4d98e15975269eff95a775a609d4a4402251b99426461050704ad8;
    uint256 amountToCollect = 25 * 1e18;
    uint256 amountToSend = amountToCollect * 4;

    // User Specific Data
    address gasPayer;
    address user;
    uint256 userPrivateKey;

    //Merkle proof for the test user
    bytes32 proofOne = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] proof = [proofOne, proofTwo];

    function setUp() public {
        if (!isZkSyncChain()) {
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.deployMerkleAirdrop();
        } else {
            token = new BagelToken();
            airdrop = new MerkleAirdrop(merkleRoot, token);
            token.mint(token.owner(), amountToSend);
            token.transfer(address(airdrop), amountToSend);
        }
        gasPayer = makeAddr("gasPayer");
        (user, userPrivateKey) = makeAddrAndKey("testUser");
        console.log("Test User: ", user);

        // address owner = address(this);
    }

    function signMessage(uint256 privKey, address account) public view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 hashedMessage = airdrop.getMessageHash(account, amountToCollect);
        (v, r, s) = vm.sign(privKey, hashedMessage);
    }

    function testUsersCanClaim() public {
        // User signs the message
        uint256 startingBalance = token.balanceOf(user);
        vm.startPrank(user);
        (uint8 v, bytes32 r, bytes32 s) = signMessage(userPrivateKey, user);
        vm.stopPrank();
        console.logBytes32(airdrop.getMerkleRoot());

        // Gas Payer pays for the gas on their behalf
        vm.prank(gasPayer);
        airdrop.claim(user, amountToCollect, proof, v, r, s);
        uint256 endingBalance = token.balanceOf(user);
        console.log("Ending Balance: ", endingBalance);
        assertEq(endingBalance - startingBalance, amountToCollect);
    }
}
