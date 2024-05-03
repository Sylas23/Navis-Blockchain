// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, console2} from "forge-std/Test.sol";
import {NavisNFT} from "../src/NavisNFT.sol";
import {NavixToken} from "../src/NavixToken.sol";

contract NavisNFTTest is Test {
    NavisNFT public navisNFT;
    NavixToken public navixToken;
    address deployer = address(1);
    address user = address(2);
    address user2 = address(3);
    address user3 = address(4);
    address user4 = address(5);

    function setUp() public {
        navixToken = new NavixToken();
        navisNFT = new NavisNFT(address(navixToken));
        uint256 tokensToMint = 200000 ether;
        navixToken.mint(user, tokensToMint);
        navixToken.mint(user2, tokensToMint);
        navixToken.mint(user3, tokensToMint);
        navixToken.mint(user4, tokensToMint);
    }

    function testTotalFreeNFTMint() public {
        uint256 TOTAL_FREE_NFT = 6; // The user should not have more than 6 free NFTs

        vm.startPrank(user);
        navisNFT.mintFree();
        vm.stopPrank();

        uint256[] memory balanceOfUser = new uint256[](TOTAL_FREE_NFT);

        for (uint256 i = 0; i < TOTAL_FREE_NFT; i++) {
            balanceOfUser[i] = navisNFT.balanceOf(user, i);
        }

        for (uint256 j = 0; j < TOTAL_FREE_NFT; j++) {
            assert(balanceOfUser[j] == 1); // Ensure the user received exactly one NFT of each type
        }

        uint256 totalNFTsMinted = 0;
        for (uint256 k = 0; k < TOTAL_FREE_NFT; k++) {
            totalNFTsMinted += balanceOfUser[k];
        }

        console.log("Total free nft minted:", totalNFTsMinted);

        assert(totalNFTsMinted == TOTAL_FREE_NFT);
    }

    function testPremiumNFTMintPayment() public {
        uint256 shipType = 8;
        uint256 mintPrice = 200 * 10 ** 18;

        uint256 userNavixBalBefore = navixToken.balanceOf(user);
        console.log("User Navix Balance Before Mint:", userNavixBalBefore);

        vm.startPrank(user);

        require(navixToken.approve(address(navisNFT), mintPrice), "Approval failed");

        navisNFT.mintPremium(shipType);

        vm.stopPrank();

        uint256 balanceOfUser = navisNFT.balanceOf(user, shipType);
        console.log("Balance of Premium NFT:", balanceOfUser);

        uint256 userNavixBalAfter = navixToken.balanceOf(user);
        console.log("User Navix Balance After Mint:", userNavixBalAfter);

        assert(userNavixBalBefore - userNavixBalAfter == mintPrice);
    }

    function testMultipleUserNFTIDDoesNotClash() public {
        uint256[] memory shipTypes = new uint256[](5);
        shipTypes[0] = 6;
        shipTypes[1] = 7;
        shipTypes[2] = 8;
        shipTypes[3] = 9;
        shipTypes[4] = 10;
        uint256 mintPrice = 200 * 10 ** 18;
        address[] memory users = new address[](4);
        users[0] = user;
        users[1] = user2;
        users[2] = user3;
        users[3] = user4;

        uint256[] memory allPremiumNFTIDs = new uint256[](shipTypes.length * users.length);

        uint256 index = 0; // Index for tracking NFT IDs in the array

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);

            // Ensure the user has enough tokens and approves the transaction
            uint256 userBalanceBefore = navixToken.balanceOf(users[i]);
            console.log("User balance before minting:", userBalanceBefore);
            assert(userBalanceBefore >= mintPrice * shipTypes.length);
            require(navixToken.approve(address(navisNFT), mintPrice * shipTypes.length), "Approval failed");

            // Mint multiple premium NFTs and check for ID clashes
            for (uint256 j = 0; j < shipTypes.length; j++) {
                uint256 newPremiumNFTID = navisNFT.mintPremium(shipTypes[j]);
                console.log("User", uint256(uint160(users[i])));
                console.log("User minted NFT ID", newPremiumNFTID);
                console.log("of type for User", shipTypes[j]);

                // Check if this new NFT ID has been minted before by any user
                for (uint256 k = 0; k < index; k++) {
                    assert(allPremiumNFTIDs[k] != newPremiumNFTID);
                }

                // Store the new NFT ID in the array
                allPremiumNFTIDs[index] = newPremiumNFTID;
                index++;
            }

            uint256 userBalanceAfter = navixToken.balanceOf(users[i]);
            console.log("User balance after minting:", userBalanceAfter);
            vm.stopPrank();
        }
    }

    function testUpdateShipAbilitiesUnauthorized(uint256 _id, string[] memory _abilities) public {
        // Creating a temporary memory array to hold the new abilities
        string[] memory newAbilities = new string[](2);
        newAbilities[0] = "Gun";
        newAbilities[1] = "Axe";

        // Get the abilities before update attempt to compare later
        string[] memory initialAbilities = navisNFT.getPremiumShipAbilities(7);

        // Attempt to update abilities by a non-admin user
        vm.startPrank(user2);
        bool updateSuccess = false;
        try navisNFT.updateShipAbilities(_id, _abilities) {
            updateSuccess = true;
        } catch {
            updateSuccess = false;
        }
        vm.stopPrank();

        // Fetch the abilities after the attempted update
        string[] memory updatedAbilities = navisNFT.getPremiumShipAbilities(_id);

        // Log the abilities to verify output
        console.log("Initial Abilities:");
        for (uint256 i = 0; i < initialAbilities.length; i++) {
            console.log(initialAbilities[i]);
        }
        console.log("Updated Abilities:");
        for (uint256 i = 0; i < updatedAbilities.length; i++) {
            console.log(updatedAbilities[i]);
        }

        // Assert that the update was unsuccessful and abilities remain unchanged
        assert(!updateSuccess);
        // for (uint256 i = 0; i < initialAbilities.length; i++) {
        //     assert(
        //         keccak256(bytes(initialAbilities[i])) == keccak256(bytes(updatedAbilities[i])),
        //         "Abilities should not change after an unauthorized update attempt"
        //     );
        // }
    }
}
