// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, console2} from "forge-std/Test.sol";
import {NavisNFT} from "../src/NavisNFT.sol";
import {NavixToken} from "../src/NavixToken.sol";
import {NavisMarketplace} from "../src/NavisMarketplace.sol";

event Listed(uint256 indexed tokenId, uint256 price, address seller);
event Sale(uint256 indexed tokenId, uint256 price, address seller, address buyer);
event Unlisted(uint256 indexed tokenId);
event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);
event BidPlaced(uint256 indexed tokenId, address bidder, uint256 bid);
event AuctionExtended(uint256 indexed tokenId, uint256 newEndTime);

contract NFTMarketplaceTest is Test {
    NavisNFT public navisNFT;
    NavixToken public navixToken;
    NavisMarketplace public navisMarketplace;
    address deployer = address(1);
    address user = address(2);
    address user2 = address(3);
    address user3 = address(4);
    address user4 = address(5);

    uint256 constant mintPrice = 200 * 10 ** 18;
    uint256 constant tokensToMint = 200000 ether;

    function setUp() public {
        navixToken = new NavixToken();
        navisNFT = new NavisNFT(address(navixToken));
        navisMarketplace = new NavisMarketplace(address(navisNFT), address(navixToken));

        // Mint tokens for each user
        address[] memory users = new address[](5);
        users[0] = deployer;
        users[1] = user;
        users[2] = user2;
        users[3] = user3;
        users[4] = user4;

        for (uint256 i = 0; i < users.length; i++) {
            navixToken.mint(users[i], tokensToMint);
        }
    }

    function testMintPremium() public {
        uint256 shipType = 8;
        uint256 userNavixBalBefore = navixToken.balanceOf(user);
        console.log("User Navix Balance Before Mint:", userNavixBalBefore);

        vm.startPrank(user);
        require(navixToken.approve(address(navisNFT), mintPrice), "Approval failed");
        uint256 newTokenID = navisNFT.mintPremium(shipType);
        vm.stopPrank();

        uint256 userNavixBalAfter = navixToken.balanceOf(user);
        console.log("User Navix Balance After Mint:", userNavixBalAfter);

        assertEq(userNavixBalBefore - userNavixBalAfter, mintPrice, "Mint price was not deducted correctly");
        assert(newTokenID > 5);
    }

    function testListForSale() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, false, 1714603946);

        // Expect the Listed event to be emitted with specific parameters
        vm.expectEmit(true, false, false, false);
        emit Listed(newTokenID, 300 ether, user);
    }

    function testBuyTokenOnSale_NotAuction() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, false, uint64(block.timestamp) + 100000);
        uint256 user2NavixBalBefore = navixToken.balanceOf(user2);

        // Simulate user2 buying the listed token
        vm.startPrank(user2);
        require(navixToken.approve(address(navisMarketplace), 300 ether), "Approval failed");

        // Expecting the Sale event to be emitted
        vm.expectEmit(true, false, false, true);
        emit Sale(newTokenID, 300 ether, user, user2);

        navisMarketplace.buyToken(newTokenID);
        vm.stopPrank();

        assertEq(navisNFT.balanceOf(user2, newTokenID), 1, "User2 should now own the NFT");
        console.log("Seller Balance after sale:", navixToken.balanceOf(user));
    }

    function testBuyTokenOnAuction() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, true, 1714603946);

        // user2 calling "buy" instead of "bid" on the auctioned token
        vm.startPrank(user2);
        require(navixToken.approve(address(navisMarketplace), 300 ether), "Approval failed");

        // Confirm Revert
        vm.expectRevert(bytes("Token currently on auction"));
        navisMarketplace.buyToken(newTokenID);
        vm.stopPrank();

        // Confirm buyer doesn't get NFT
        assertEq(navisNFT.balanceOf(user2, newTokenID), 0, "User2 should not own the NFT");
        assertEq(navisNFT.balanceOf(user, newTokenID), 1, "User should still own the NFT");
    }

    function testBidForTokenOnAuction() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, true, uint64(block.timestamp) + 1 days);

        placeBid(user2, newTokenID, 350 ether);
        placeBid(user3, newTokenID, 400 ether);

        // Concluding Auction
        skip(1 days + 1 hours);
        vm.startPrank(user);
        vm.expectEmit(true, false, false, false);
        emit Sale(newTokenID, 400 ether, user, user3);
        navisMarketplace.concludeAuction(newTokenID);
        vm.stopPrank();

        // Confirm highest bidder gets NFT
        assertEq(navisNFT.balanceOf(user3, newTokenID), 1, "User3 should win the auction");
        assertEq(navisNFT.balanceOf(user, newTokenID), 0, "User should no longer own the NFT");
    }

    function testUnlistToken() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, true, uint64(block.timestamp) + 1 days);

        vm.startPrank(user);
        navisMarketplace.unlistToken(newTokenID);
        vm.stopPrank();

        NavisMarketplace.Listing memory listingData = navisMarketplace.getListingData(newTokenID);
        assertEq(listingData.tokenId, 0);
        assertEq(listingData.price, 0);
        assertEq(listingData.seller, address(0));
    }

    function testPauseAndUnpauseListing() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, true, uint64(block.timestamp) + 1 days);

        // Pausing listing by user
        vm.startPrank(user);
        navisMarketplace.pauseListing(newTokenID);
        vm.stopPrank();

        // Attempting to bid should revert
        vm.startPrank(user2);
        vm.expectRevert(bytes("Listing currently paused"));
        navisMarketplace.placeBid(newTokenID, 302 ether);
        vm.stopPrank();

        // Unpausing listing by user
        vm.startPrank(user);
        navisMarketplace.unpauseListing(newTokenID);
        vm.stopPrank();

        // Attempting to bid should not revert
        placeBid(user2, newTokenID, 302 ether);
    }

    function testUpdateListing() public {
        uint256 newTokenID = mintAndListToken(user, 8, 300 ether, true, uint64(block.timestamp) + 1 days);

        vm.startPrank(user);
        navisMarketplace.updateListing(newTokenID, 310 ether);
        vm.stopPrank();

        NavisMarketplace.Listing memory listingDataUpdate = navisMarketplace.getListingData(newTokenID);
        assertEq(listingDataUpdate.price, 310 ether);
    }

    function mintAndListToken(
        address userAddress,
        uint256 shipType,
        uint256 price,
        bool isAuction,
        uint64 auctionDuration
    ) internal returns (uint256) {
        vm.startPrank(userAddress);
        require(navixToken.approve(address(navisNFT), mintPrice), "Approval failed");
        uint256 newTokenID = navisNFT.mintPremium(shipType);
        navisNFT.setApprovalForAll(address(navisMarketplace), true);
        navisMarketplace.listToken(newTokenID, price, isAuction, auctionDuration);
        vm.stopPrank();
        return newTokenID;
    }

    function placeBid(address bidder, uint256 tokenId, uint256 bidAmount) internal {
        vm.startPrank(bidder);
        require(navixToken.approve(address(navisMarketplace), bidAmount), "Approval failed");
        navisMarketplace.placeBid(tokenId, bidAmount);
        vm.stopPrank();
    }
}
