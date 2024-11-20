// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NavisMarketplace.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockNFT is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("NavisToken", "NAVIS") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract NavisMarketplaceTest is Test {
    NavisMarketplace public marketplace;
    MockNFT public nft;
    MockToken public navisToken;

    address owner = address(1);
    address seller = address(2);
    address buyer = address(3);
    address bidder = address(4);

    function setUp() public {
        // Deploy mock contracts
        nft = new MockNFT();
        navisToken = new MockToken();

        // Deploy marketplace and set roles
        vm.prank(owner);
        marketplace = new NavisMarketplace(address(nft), address(navisToken));

        // Allocate NAVIS tokens
        navisToken.mint(seller, 100 ether);
        navisToken.mint(buyer, 100 ether);
        navisToken.mint(bidder, 100 ether);

        // Approve marketplace for NAVIS tokens
        vm.prank(seller);
        navisToken.approve(address(marketplace), type(uint256).max);
        vm.prank(buyer);
        navisToken.approve(address(marketplace), type(uint256).max);
        vm.prank(bidder);
        navisToken.approve(address(marketplace), type(uint256).max);

        // Mint NFTs to seller
        vm.prank(seller);
        nft.mint(seller, 1, 1); // Token ID 1
        vm.prank(seller);
        nft.setApprovalForAll(address(marketplace), true);
    }

    function testListToken() public {
        vm.prank(seller);
        marketplace.listToken(1, 10 ether, false, 0);

        NavisMarketplace.Listing memory listing = marketplace.getListingData(1);
        assertEq(listing.price, 10 ether);
        assertEq(listing.seller, seller);
        assertEq(listing.isAuction, false);
    }

    function testBuyToken() public {
        vm.prank(seller);
        marketplace.listToken(1, 10 ether, false, 0);

        vm.prank(buyer);
        marketplace.buyToken(1);

        assertEq(nft.balanceOf(buyer, 1), 1);
        assertEq(nft.balanceOf(seller, 1), 0);
        assertEq(navisToken.balanceOf(seller), 110 ether);
    }

    function testPlaceBid() public {
        vm.prank(seller);
        marketplace.listToken(1, 10 ether, true, 1 days);

        vm.prank(bidder);
        marketplace.placeBid(1, 11 ether);

        NavisMarketplace.Listing memory listing = marketplace.getListingData(1);
        assertEq(listing.highestBid, 11 ether);
        assertEq(listing.highestBidder, bidder);
    }

    function testConcludeAuction() public {
        vm.prank(seller);
        marketplace.listToken(1, 10 ether, true, 1 days);

        vm.prank(bidder);
        marketplace.placeBid(1, 11 ether);

        vm.warp(block.timestamp + 2 days);

        vm.prank(seller);
        marketplace.concludeAuction(1);

        assertEq(nft.balanceOf(bidder, 1), 1);
        assertEq(nft.balanceOf(seller, 1), 0);
        assertEq(navisToken.balanceOf(seller), 111 ether);
    }

    function testUnlistToken() public {
        vm.prank(seller);
        marketplace.listToken(1, 10 ether, false, 0);

        vm.prank(seller);
        marketplace.unlistToken(1);

        NavisMarketplace.Listing memory listing = marketplace.getListingData(1);
        assertEq(listing.tokenId, 0); // Token should be unlisted
    }

    function testPauseAndUnpauseListing() public {
        vm.prank(seller);
        marketplace.listToken(1, 10 ether, false, 0);

        vm.prank(owner);
        marketplace.pauseListing(1);

        vm.expectRevert("Listing currently paused");
        vm.prank(buyer);
        marketplace.buyToken(1);

        vm.prank(owner);
        marketplace.unpauseListing(1);

        vm.prank(buyer);
        marketplace.buyToken(1);

        assertEq(nft.balanceOf(buyer, 1), 1);
    }

    function testBlacklistUser() public {

        vm.prank(seller);
        marketplace.listToken(1, 10 ether, false, 0);

        vm.prank(owner);
        marketplace.blacklistUser(buyer);

        vm.expectRevert("Buyer is blacklisted");
        vm.prank(buyer);
        marketplace.buyToken(1);
    }

    function testRescueERC20() public {
        uint256 initialBalance = navisToken.balanceOf(owner);

        vm.prank(buyer);
        navisToken.transfer(address(marketplace), 10 ether);

        vm.prank(owner);
        marketplace.rescueERC20(address(navisToken), 10 ether);

        assertEq(navisToken.balanceOf(owner), initialBalance + 10 ether);
    }

    function testRescueERC1155() public {
        vm.prank(seller);
        nft.safeTransferFrom(seller, address(marketplace), 1, 1, "");

        vm.prank(owner);
        marketplace.rescueERC1155(address(nft), 1, 1);

        assertEq(nft.balanceOf(owner, 1), 1);
    }
}
