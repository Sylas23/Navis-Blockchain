// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NavixToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract NavixTokenTest is Test {
    NavixToken private navixToken;
    address private owner;
    address private pauser;
    address private minter;
    address private rescuer;
    address private user;

    function setUp() public {
        owner = address(this);
        pauser = address(0x1);
        minter = address(0x2);
        rescuer = address(0x3);
        user = address(0x4);

        // Deploy NavixToken
        navixToken = new NavixToken();

        // Assign roles
        navixToken.grantRole(navixToken.PAUSER_ROLE(), pauser);
        navixToken.grantRole(navixToken.MINTER_ROLE(), minter);
        navixToken.grantRole(navixToken.RESCUER_ROLE(), rescuer);
    }

    function testInitialSetup() public view {
        assertEq(navixToken.name(), "Navix");
        assertEq(navixToken.symbol(), "Navix");
        assertEq(navixToken.totalSupply(), 0);
        assertEq(navixToken.getMaxTotalSupply(), 1_000_000_000e18);

        // Check role assignments
        assertTrue(navixToken.hasRole(navixToken.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(navixToken.hasRole(navixToken.PAUSER_ROLE(), pauser));
        assertTrue(navixToken.hasRole(navixToken.MINTER_ROLE(), minter));
        assertTrue(navixToken.hasRole(navixToken.RESCUER_ROLE(), rescuer));
    }

    function testMinting() public {
        uint256 mintAmount = 100e18;

        // Mint tokens
        vm.prank(minter);
        navixToken.mint(user, mintAmount);

        // Verify balances and total supply
        assertEq(navixToken.balanceOf(user), mintAmount);
        assertEq(navixToken.totalSupply(), mintAmount);
    }

    function testMintingExceedsMaxSupply() public {
        uint256 excessiveAmount = navixToken.getMaxTotalSupply() + 1;

        // Attempt to mint more than the max supply
        vm.prank(minter);
        vm.expectRevert("NAVIX: Max total supply exceeded");
        navixToken.mint(user, excessiveAmount);
    }

    function testPausingAndUnpausing() public {
        uint256 mintAmount = 50e18;

        // Pause the contract
        vm.prank(pauser);
        navixToken.pause();
        assertTrue(navixToken.paused());

        // Ensure minting fails while paused
        vm.prank(minter);
        vm.expectRevert();
        navixToken.mint(user, mintAmount);

        // Unpause the contract
        vm.prank(pauser);
        navixToken.unpause();
        assertFalse(navixToken.paused());

        // Minting should now succeed
        vm.prank(minter);
        navixToken.mint(user, mintAmount);
        assertEq(navixToken.balanceOf(user), mintAmount);
    }

    function testNonAdminCannotPause() public {
        // Non-admin user attempts to pause
        vm.prank(user);
        vm.expectRevert();
        navixToken.pause();
    }

    function testTokenRescue() public {
        uint256 rescueAmount = 50e18;

        // Deploy a mock ERC20 token
        ERC20Mock mockToken = new ERC20Mock("MockToken", "MOCK", user, rescueAmount);

        // Transfer tokens to NavixToken contract
        vm.prank(user);
        mockToken.transfer(address(navixToken), rescueAmount);

        // Rescue tokens
        uint256 rescuerInitialBalance = mockToken.balanceOf(rescuer);
        vm.prank(rescuer);
        navixToken.rescueTokens(mockToken, rescueAmount);

        // Verify balances
        assertEq(mockToken.balanceOf(rescuer), rescuerInitialBalance + rescueAmount);
    }
}

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol, address initialAccount, uint256 initialBalance)
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
    }
}
