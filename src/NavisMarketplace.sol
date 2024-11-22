// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

//TODO: Implement protocol fee feature. VITAL

contract NavisMarketplace is ERC1155Holder, ReentrancyGuard, Ownable, Pausable {
    IERC1155 public immutable nftContract;
    IERC20 public immutable navisToken;
    uint256 fee;

    struct Listing {
        uint256 tokenId;
        uint256 price;
        address seller;
        bool isAuction;
        uint64 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
    }

    struct HistoryEntry {
        uint256 price;
        address seller;
        address buyer;
        uint64 timestamp;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => HistoryEntry[]) public tokenHistories;
    mapping(uint256 => bool) public listingPaused;
    mapping(address => bool) public blacklisted;
    uint64 public constant MIN_EXTENSION_TIME = 2 minutes;
    uint256 public minBidPercentageIncrement = 5; // 5% minimum increment
    uint256[] public activeTokenIds;

    event Listed(uint256 indexed tokenId, uint256 price, address seller);
    event Sale(
        uint256 indexed tokenId,
        uint256 price,
        address seller,
        address buyer
    );
    event Unlisted(uint256 indexed tokenId);
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 bid);
    event AuctionExtended(uint256 indexed tokenId, uint256 newEndTime);

    constructor(address _nftContract, address _navisToken) Ownable(msg.sender) {
        require(
            _nftContract != address(0),
            "NFT contract address cannot be zero."
        );
        require(
            _navisToken != address(0),
            "Navis token address cannot be zero."
        );
        nftContract = IERC1155(_nftContract);
        navisToken = IERC20(_navisToken);
    }

    function listToken(
        uint256 tokenId,
        uint256 price,
        bool isAuction,
        uint64 auctionDuration
    ) public nonReentrant {
        require(
            nftContract.balanceOf(msg.sender, tokenId) > 0,
            "Seller must own the token."
        );
        require(
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "Contract must be approved to manage seller's tokens."
        );
        require(
            listings[tokenId].tokenId == 0,
            "Token is already listed or auctioned."
        );

        listings[tokenId] = Listing({
            tokenId: tokenId,
            price: price,
            seller: msg.sender,
            isAuction: isAuction,
            auctionEndTime: isAuction
                ? uint64(block.timestamp) + auctionDuration
                : 0,
            highestBidder: address(0),
            highestBid: 0
        });
        activeTokenIds.push(tokenId);
        emit Listed(tokenId, price, msg.sender);
    }

    // Batch list tokens
    function batchListTokens(
        uint256[] memory tokenIds,
        uint256[] memory prices,
        bool[] memory isAuctions,
        uint64[] memory durations
    ) public isNotBlacklisted nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            listToken(tokenIds[i], prices[i], isAuctions[i], durations[i]);
        }
    }

    // Batch unlist tokens
    function batchUnlistTokens(
        uint256[] memory tokenIds
    ) public isNotBlacklisted {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            unlistToken(tokenIds[i]);
        }
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function buyToken(uint256 tokenId) public whenNotPaused nonReentrant {
        Listing memory listing = listings[tokenId];
        require(!blacklisted[msg.sender], "Buyer is blacklisted");
        require(listing.price > 0, "Token must be listed.");
        require(listing.isAuction == false, "Token currently on auction");

        require(listingPaused[tokenId] == false, "Listing currently paused");
        uint256 totalPrice = listing.price + fee;
        require(
            navisToken.transferFrom(msg.sender, listing.seller, totalPrice),
            "Payment transfer failed."
        );
        nftContract.safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId,
            1,
            ""
        );
        emit Sale(tokenId, listing.price, listing.seller, msg.sender);
        delete listings[tokenId];

        updateHistory(tokenId, listing.seller, msg.sender, listing.price);
    }

    function unlistToken(uint256 tokenId) public nonReentrant {
        require(
            listings[tokenId].seller == msg.sender,
            "Only seller can unlist the token."
        );
        emit Unlisted(tokenId);
        removeTokenId(tokenId); // Implement this to remove token ID from activeTokenIds
        delete listings[tokenId];
    }

    function getListingData(
        uint256 _tokenId
    ) public view returns (Listing memory) {
        return listings[_tokenId];
    }

    function queryListings(
        uint256 minPrice,
        uint256 maxPrice,
        bool isAuction
    ) public view returns (Listing[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeTokenIds.length; i++) {
            if (
                (listings[activeTokenIds[i]].price >= minPrice) &&
                (listings[activeTokenIds[i]].price <= maxPrice) &&
                listings[activeTokenIds[i]].isAuction == isAuction
            ) {
                count++;
            }
        }

        Listing[] memory filteredListings = new Listing[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < activeTokenIds.length; i++) {
            if (
                (listings[activeTokenIds[i]].price >= minPrice) &&
                (listings[activeTokenIds[i]].price <= maxPrice) &&
                listings[activeTokenIds[i]].isAuction == isAuction
            ) {
                filteredListings[index] = listings[activeTokenIds[i]];
                index++;
            }
        }
        return filteredListings;
    }

    /**
     * @dev Removes a tokenId from the activeTokenIds array by value.
     * It finds the element, swaps it with the last element, and then removes the last element.
     * @param tokenId The tokenId to remove.
     */
    function removeTokenId(uint256 tokenId) internal {
        // Find the index of the tokenId in the activeTokenIds array
        uint256 index = findTokenIdIndex(tokenId);
        require(index < activeTokenIds.length, "Token ID not found");

        // Move the last element into the place to delete
        activeTokenIds[index] = activeTokenIds[activeTokenIds.length - 1];

        // Remove the last element
        activeTokenIds.pop();
    }

    /**
     * @dev Finds the index of a tokenId in the activeTokenIds array.
     * @param tokenId The tokenId to find.
     * @return uint256 The index of the tokenId.
     */
    function findTokenIdIndex(uint256 tokenId) internal view returns (uint256) {
        for (uint256 i = 0; i < activeTokenIds.length; i++) {
            if (activeTokenIds[i] == tokenId) {
                return i;
            }
        }
        revert("Token ID not found in the active list");
    }

    function placeBid(
        uint256 tokenId,
        uint256 bidAmount
    ) public nonReentrant isNotBlacklisted {
        Listing storage listing = listings[tokenId];
        require(listingPaused[tokenId] == false, "Listing currently paused");
        require(listing.isAuction, "This token is not up for auction.");
        require(
            block.timestamp < listing.auctionEndTime,
            "The auction has ended."
        );

        uint256 minRequiredBid = listing.highestBid +
            ((listing.highestBid * minBidPercentageIncrement) / 100);
        require(
            bidAmount >= minRequiredBid,
            "Bid must be at least the minimum percentage increment higher than the current highest bid."
        );

        uint256 totalbid = bidAmount + fee;

        // Transfer the bid amount in navisToken from the bidder to this contract
        require(
            navisToken.transferFrom(msg.sender, address(this), totalbid),
            "Failed to transfer tokens for bid"
        );

        if (listing.highestBidder != address(0)) {
            require(
                navisToken.transfer(listing.highestBidder, listing.highestBid),
                "Failed to refund the previous bidder"
            );
        }

        listing.highestBidder = msg.sender;
        listing.highestBid = bidAmount;

        // Extend auction if bid is within the last MIN_EXTENSION_TIME minutes
        if (listing.auctionEndTime - block.timestamp <= MIN_EXTENSION_TIME) {
            listing.auctionEndTime += MIN_EXTENSION_TIME;
            emit AuctionExtended(tokenId, listing.auctionEndTime);
        }

        emit BidPlaced(tokenId, msg.sender, bidAmount);
    }

    function updateHistory(
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price
    ) internal {
        tokenHistories[tokenId].push(
            HistoryEntry({
                price: price,
                seller: seller,
                buyer: buyer,
                timestamp: uint64(block.timestamp)
            })
        );
    }

    // Setter in case we do minimum bid increment %
    // function setMinBidPercentageIncrement(uint256 _minBidPercentageIncrement) public onlyOwner {
    //     require(_minBidPercentageIncrement > 0, "Increment must be positive.");
    //     minBidPercentageIncrement = _minBidPercentageIncrement;
    // }

    function concludeAuction(uint256 tokenId) public nonReentrant {
        Listing storage listing = listings[tokenId];
        require(listing.isAuction, "This token is not auctioned.");
        require(
            block.timestamp >= listing.auctionEndTime,
            "The auction is not yet over."
        );
        require(
            msg.sender == listing.seller || msg.sender == owner(),
            "Only seller or owner can conclude the auction."
        );

        if (listing.highestBidder != address(0)) {
            nftContract.safeTransferFrom(
                listing.seller,
                listing.highestBidder,
                tokenId,
                1,
                ""
            );
            require(
                navisToken.transfer(listing.seller, listing.highestBid),
                "Failed to transfer funds to seller"
            );

            emit Sale(
                tokenId,
                listing.highestBid,
                listing.seller,
                listing.highestBidder
            );

            updateHistory(
                tokenId,
                listing.seller,
                listing.highestBidder,
                listing.highestBid
            );
        } else {
            // case where there were no bids
        }

        removeTokenId(tokenId);
        delete listings[tokenId];
    }

    function pauseListing(uint256 tokenId) public {
        require(
            listings[tokenId].seller == msg.sender || owner() == msg.sender,
            "Not authorized"
        );
        listingPaused[tokenId] = true;
    }

    function unpauseListing(uint256 tokenId) public {
        require(
            listings[tokenId].seller == msg.sender || owner() == msg.sender,
            "Not authorized"
        );
        listingPaused[tokenId] = false;
    }

    function updateListing(uint256 tokenId, uint256 newPrice) public {
        require(newPrice > 0, "Price must be greater than zero.");
        require(listingPaused[tokenId] == false, "Listing currently paused");

        require(
            listings[tokenId].seller == msg.sender,
            "Only seller can update the listing."
        );
        listings[tokenId].price = newPrice;
        emit PriceUpdated(tokenId, newPrice);
    }

    function rescueERC20(
        address tokenAddress,
        uint256 amount
    ) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    function rescueERC1155(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) public onlyOwner {
        IERC1155(tokenAddress).safeTransferFrom(
            address(this),
            owner(),
            tokenId,
            amount,
            ""
        );
    }

    function blacklistUser(address user) public onlyOwner {
        blacklisted[user] = true;
    }

    function unblacklistUser(address user) public onlyOwner {
        blacklisted[user] = false;
    }

    modifier isNotBlacklisted() {
        require(!blacklisted[msg.sender], "Caller is blacklisted");
        _;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
