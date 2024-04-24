// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NavisNFT} from "../src/NavisNFT.sol";
import {NavisToken} from "../src/NavisToken.sol";



contract NavisNFTTest is Test {
    NavisNFT public navisNFT;
    NavisToken public navisToken;
    address deployer = address(1);
    address user = address(2);

    function setUp() public {
        navisToken = new NavisToken();
        navisNFT = new NavisNFT(deployer, deployer, deployer, deployer, address(navisToken));
    }

    function testNFTMint(uint256 id, uint256 amount) public {
        // uint256 id = 1;
        // uint256 amount = 3;

        vm.startPrank(user);
        navisNFT.mint(id, amount);

        vm.stopPrank();

        uint256 balanceOfUser = navisNFT.balanceOf(user, 1);

        assert(balanceOfUser == amount);
    }

    
}
