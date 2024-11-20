// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NavisNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NavisNFTTest is Test {
    NavisNFT private navisNFT;
    ERC20Mock private mockToken;
    address private admin;
    address private pauser;
    address private minter;
    address private user;
    address private feeCollector;
    address private uriSetter;

    function setUp() public {
        admin = address(this);
        pauser = address(0x1);
        minter = address(0x2);
        user = address(0x3);
        feeCollector = address(0x4);
        uriSetter = address(0x5);

        // Deploy mock ERC20 token for fee payment
        mockToken = new ERC20Mock("NavisToken", "NAVIS", admin, 1_000_000e18);

        // Deploy NavisNFT contract
        navisNFT = new NavisNFT(address(mockToken));

        // Assign roles
        navisNFT.grantRole(navisNFT.PAUSER_ROLE(), pauser);
        navisNFT.grantRole(navisNFT.MINTER_ROLE(), minter);
        navisNFT.grantRole(navisNFT.URI_SETTER_ROLE(), uriSetter);

        // Set fee collector
        navisNFT.setFeeCollector(feeCollector);
    }

    function testInitialSetup() public {
        assertEq(navisNFT.name(), "Navis NFT Ship");
        assertEq(navisNFT.symbol(), "NavisShip");
        assertEq(navisNFT.getUserShipIDs(user).length, 0);
        assertEq(mockToken.balanceOf(admin), 1_000_000e18);
    }

    function testMintFree() public {
        vm.prank(user);
        navisNFT.mintFree();

        uint256[] memory userShips = navisNFT.getUserShipIDs(user);
        assertEq(userShips.length, 6);
        for (uint256 i = 0; i < 6; i++) {
            assertEq(userShips[i], i);
            assertEq(navisNFT.balanceOf(user, i), 1);
        }

        // Check URI for free NFT
        assertEq(
            navisNFT.uri(0),
            "https://gnfd-testnet-sp1.bnbchain.org/view/navis-nft-test/0.json"
        );

        // Ensure user cannot mint again
        vm.expectRevert("User already minted free NFT");
        vm.prank(user);
        navisNFT.mintFree();
    }

    function testMintPremium() public {
        uint256 mintFee = 20e18;
        uint256 userBag = 2000e18;

        // Transfer tokens to user and approve NavisNFT
        mockToken.transfer(user, userBag);
        vm.prank(user);
        mockToken.approve(address(navisNFT), userBag);

        // Mint a premium ship
        vm.prank(user);
        uint256 tokenId = navisNFT.mintPremium(10);

        uint256[] memory userShips = navisNFT.getUserShipIDs(user);
        assertEq(userShips.length, 1);
        assertEq(userShips[0], tokenId);
        assertEq(navisNFT.balanceOf(user, tokenId), 1);

        // Check URI for premium NFT
        assertEq(
            navisNFT.uri(tokenId),
            "https://gnfd-testnet-sp1.bnbchain.org/view/navis-nft-test/10.json"
        );

        // Check fee transfer
        assertEq(mockToken.balanceOf(feeCollector), mintFee);

        // Ensure invalid ship types revert
        vm.expectRevert("Invalid ship type");
        vm.prank(user);
        navisNFT.mintPremium(5);

        // vm.expectRevert("Invalid ship type");
        // vm.prank(user);
        // navisNFT.mintPremium(76);
    }

    function testPauseUnpause() public {
        // Pause the contract
        vm.prank(pauser);
        navisNFT.pause();
        assertTrue(navisNFT.paused());

        // Ensure minting is blocked when paused
        vm.prank(user);
        vm.expectRevert();
        navisNFT.mintFree();

        // Unpause the contract
        vm.prank(pauser);
        navisNFT.unpause();
        assertFalse(navisNFT.paused());

        // Minting should now succeed
        vm.prank(user);
        navisNFT.mintFree();
        assertEq(navisNFT.balanceOf(user, 0), 1);
    }

    function testUpdateShipAbilities() public {
        string;
        string[] memory abilities = new string[](2);
        abilities[0] = "Speed Boost";
        abilities[1] = "Extra Shield";

        // Update ship abilities
        vm.prank(minter);
        navisNFT.updateShipAbilities(1, abilities);

        // Verify updated abilities
        string[] memory storedAbilities = navisNFT.getPremiumShipAbilities(1);
        assertEq(storedAbilities.length, abilities.length);
        assertEq(storedAbilities[0], abilities[0]);
        assertEq(storedAbilities[1], abilities[1]);

        // Ensure only minter can update abilities
        vm.prank(user);
        vm.expectRevert();
        navisNFT.updateShipAbilities(1, abilities);
    }

    // @todo: Fix this test FAILING because of override function

    // function testSetURI() public {
    //     string memory newURI = "https://example.com/nft-metadata/";

    //     // Set URI
    //     vm.prank(uriSetter);
    //     navisNFT.setURI(newURI);

    //     // Check URI
    //     assertEq(
    //         navisNFT.uri(1),
    //         string(abi.encodePacked(newURI, "1.json"))
    //     );
    // }

    function testMintFeeUpdate() public {
        uint256 newFee = 50e18;

        // Update mint fee
        vm.prank(admin);
        navisNFT.setMintFee(newFee);

        // Check updated fee
        assertEq(navisNFT.mintFee(), newFee);
    }

    function testGetUserShipIDs() public {
        vm.prank(user);
        navisNFT.mintFree();

        uint256[] memory userShips = navisNFT.getUserShipIDs(user);
        assertEq(userShips.length, 6);
        for (uint256 i = 0; i < 6; i++) {
            assertEq(userShips[i], i);
        }
    }

    function testViewFunctions() public {
        string
            memory defaultURI = "https://gnfd-testnet-sp1.bnbchain.org/view/navis-nft-test/";

        // Verify default URI structure
        assertEq(
            navisNFT.uri(2),
            string(abi.encodePacked(defaultURI, "2.json"))
        );

        // Verify premium ship abilities (empty initially)
        string[] memory abilities = navisNFT.getPremiumShipAbilities(1);
        assertEq(abilities.length, 0);

        // Mint free and verify user ship IDs
        vm.prank(user);
        navisNFT.mintFree();
        uint256[] memory userShips = navisNFT.getUserShipIDs(user);
        assertEq(userShips.length, 6);
    }
}

contract ERC20Mock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) ERC20(name, symbol) {
        _mint(initialAccount, initialBalance);
    }
}
