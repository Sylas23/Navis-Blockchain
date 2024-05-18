// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NavisNFT is ERC1155, AccessControl, ERC1155Pausable, ERC1155Burnable, ERC1155Supply {
    using Counters for Counters.Counter;

    Counters.Counter public _tokenIdTracker;
    uint256 public constant PREMIUM_ID_OFFSET = 6; // Offsets premium ID from free ID to ensure Premium is non-fungible.
    uint256 fee;
    //
    mapping(uint256 => string[]) nftAbilities;

    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public name;
    string public symbol;
    //mapping (address => )
    mapping(address => bool) userHasMinted;

    // Mapping from ship ID to ship abilities
    mapping(uint256 => string[]) public shipAbilities;
    mapping(uint256 => uint256) public premiumShipID;
    mapping(address => uint256[]) public userToNFT;
    mapping(uint256 => uint256) public premiumShipIDToType;

    struct premiumShipData {
        uint256 id;
        string[] shipAbilities;
    }

    premiumShipData[] public premiumShipAbilities; // Keeps a record of the ship abilities mapped to the id.

    address public feeCollector; // Address that collects the token fees
    IERC20 public navisToken;

    uint256 public mintFee = 20 * 10 ** 18;

    // Mapping from ship type code to URI
    mapping(uint256 => string) public shipTypeURIs;

    constructor(address _navisTokenAddress) ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        feeCollector = msg.sender;
        navisToken = IERC20(_navisTokenAddress);
        name = "Navis NFT Ship";
        symbol = "NavisShip";

        // Initialize URIs for each ship type, assuming 75 types
        // for (uint256 i = 1; i <= 75; i++) {
        //     shipTypeURIs[i] = string(
        //         abi.encodePacked("https://gnfd-testnet-sp1.bnbchain.org/view/navis-nft-test/", uint2str(i), ".json")
        //     );
        // }
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setFeeCollector(address _feeCollector) public onlyRole(DEFAULT_ADMIN_ROLE) {
        feeCollector = _feeCollector;
    }

    // This is not gas efficient. How to make it gas efficient?
    // Function to update ship abilities
    function updateShipAbilities(uint256 _id, string[] memory _abilities) public onlyRole(MINTER_ROLE) {
        if (shipAbilities[_id].length == 0) {
            shipAbilities[_id] = _abilities;
        } else {
            shipAbilities[_id] = _abilities;
        }
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        uint256 shipType = tokenId < PREMIUM_ID_OFFSET ? tokenId : premiumShipIDToType[tokenId];
        return string(
            abi.encodePacked("https://gnfd-testnet-sp1.bnbchain.org/view/navis-nft-test/", uint2str(shipType), ".json")
        );
    }

    function setMintFee( uint256 _MintFee) public { 
        mintFee = _MintFee;
    }

    function getPremiumShipAbilities(uint256 _id) public view returns (string[] memory) {
        return shipAbilities[_id];
    }

    //@notice This mints fungible tokens
    function mintFree() public {
        require(!userHasMinted[msg.sender], "User already minted free NFT");
        userHasMinted[msg.sender] = true;
        for (uint256 i = 0; i < 6; i++) {
            _mint(msg.sender, i, 1, "");
            userToNFT[msg.sender].push(i);
            _setURI(shipTypeURIs[i]);
        }
    }

    //@notice This mints non-fungible tokens
    function mintPremium(uint256 shipType) public returns (uint256) {
        require(navisToken.transferFrom(msg.sender, feeCollector, mintFee), "Fee transfer failed");
        require(shipType > 5 && shipType <= 75, "Invalid ship type");
        uint256 newTokenId = _tokenIdTracker.current() + PREMIUM_ID_OFFSET;
        _mint(msg.sender, newTokenId, 1, "");
        userToNFT[msg.sender].push(newTokenId);
        premiumShipIDToType[newTokenId] = shipType;
        _setURI(shipTypeURIs[shipType]);
        _tokenIdTracker.increment();

        return newTokenId;
    }

    function getUserShipIDs(address _user) public view returns (uint256[] memory) {
        return userToNFT[_user];
    }

    function setShipTypeURI(uint256 shipType, string memory uri) public onlyRole(URI_SETTER_ROLE) {
        require(shipType > 0 && shipType <= 50, "Invalid ship type");
        shipTypeURIs[shipType] = uri;
    }

    // Helper function to convert uint256 to string
    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
