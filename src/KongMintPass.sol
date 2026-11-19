// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title KongMintPass — $KONG Mint Pass (ERC-721)
/// @notice 1 pass = 1 share of the $KONG bonding-curve sale. Passes are
///         freely transferable (standard ERC-721, auto-trades on Element).
///         Each pass records the tier it was minted at (1/2/3); the tier
///         fixes how many $KONG the pass can claim after graduation and
///         which artwork the pass shows.
///
/// @dev Minting is restricted to the KongSale contract (immutable `sale`
///      address, set in the constructor). There is no owner/admin/pause.
///
///      PER-TIER ARTWORK: each tier has its own image URI, supplied as
///      constructor parameters and never changeable afterwards (stored in
///      private storage with no setter — Solidity does not allow `string`
///      as `immutable`, so "immutable by construction" is the pattern).
///      The artwork files do NOT exist yet — the 3 URIs MUST be filled
///      with the real tier artwork locations before mainnet deploy (see
///      README). tokenURI returns fully on-chain base64 JSON metadata
///      with the tier's image embedded.
///
///      ROYALTY: ERC-2981, 5% (500 bps) to the treasury address, on every
///      secondary sale (Element honors ERC-2981).
contract KongMintPass is ERC721, ERC721Royalty {
    using Strings for uint256;

    /// @notice Maximum number of passes (== maximum number of shares).
    uint256 public constant MAX_SUPPLY = 10_000;

    /// @notice Royalty in basis points: 500 = 5%.
    uint96 public constant ROYALTY_BPS = 500;

    /// @notice The only contract allowed to mint/burn passes.
    address public immutable sale;

    /// @notice Next tokenId to mint. Token IDs are 1-based and equal the
    ///         share number (token #1 == share 1, ..., token #10000).
    uint256 public nextTokenId = 1;

    /// @notice Tier (1, 2 or 3) recorded per tokenId at mint time.
    mapping(uint256 tokenId => uint8 tier) public tierOf;

    /// @notice Claimable $KONG per tier (18 decimals), mirrored from
    ///         KongSale so the metadata can show it.
    uint256 public constant TIER1_TOKENS = 60_000 ether;
    uint256 public constant TIER2_TOKENS = 50_000 ether;
    uint256 public constant TIER3_TOKENS = 40_000 ether;

    // Tier image URIs. Set once in the constructor; no setter exists, so
    // they are immutable in practice. MUST point at the real tier artwork
    // before mainnet deploy.
    string private _tier1Image;
    string private _tier2Image;
    string private _tier3Image;

    error OnlySale();
    error MaxSupplyReached();
    error InvalidTier();

    modifier onlySale() {
        if (msg.sender != sale) revert OnlySale();
        _;
    }

    constructor(
        address sale_,
        address treasury_,
        string memory tier1Image_,
        string memory tier2Image_,
        string memory tier3Image_
    ) ERC721("Kong Mint Pass", "KONGPASS") {
        require(sale_ != address(0), "sale zero");
        require(treasury_ != address(0), "treasury zero");
        sale = sale_;
        _tier1Image = tier1Image_;
        _tier2Image = tier2Image_;
        _tier3Image = tier3Image_;
        _setDefaultRoyalty(treasury_, ROYALTY_BPS);
    }

    /// @notice Image URI for a tier (1, 2 or 3). Public so frontends and
    ///         marketplaces can read a tier's artwork without decoding
    ///         tokenURI.
    function tierImageURI(uint8 tier) public view returns (string memory) {
        if (tier == 1) return _tier1Image;
        if (tier == 2) return _tier2Image;
        if (tier == 3) return _tier3Image;
        revert InvalidTier();
    }

    /// @notice Claimable $KONG for a tokenId, derived from its tier.
    function claimableOf(uint256 tokenId) public view returns (uint256) {
        uint8 tier = tierOf[tokenId];
        if (tier == 1) return TIER1_TOKENS;
        if (tier == 2) return TIER2_TOKENS;
        if (tier == 3) return TIER3_TOKENS;
        revert InvalidTier();
    }

    /// @notice Mint one pass to `to` with the given tier. Sale only.
    /// @return tokenId The newly minted tokenId (= share number).
    function mint(address to, uint8 tier) external onlySale returns (uint256 tokenId) {
        if (tier < 1 || tier > 3) revert InvalidTier();
        tokenId = nextTokenId;
        if (tokenId > MAX_SUPPLY) revert MaxSupplyReached();
        unchecked {
            ++nextTokenId;
        }
        tierOf[tokenId] = tier;
        _safeMint(to, tokenId);
    }

    /// @notice Burn a pass (called by the sale on claim/refund). Sale only.
    function burn(uint256 tokenId) external onlySale {
        _burn(tokenId);
        delete tierOf[tokenId];
    }

    /// @notice Fully on-chain JSON metadata (base64 data URI). The `image`
    ///         field is the artwork of the token's own tier, so Tier 1/2/3
    ///         passes display different art.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint8 tier = tierOf[tokenId];
        string memory image = tierImageURI(tier);
        uint256 claimable = claimableOf(tokenId);

        string memory json = string.concat(
            '{"name":"Kong Mint Pass #',
            tokenId.toString(),
            '","description":"Mint Pass for the $KONG bonding-curve sale. 1 pass = 1 share. Claimable after graduation; claiming burns this pass. Tier ',
            uint256(tier).toString(),
            ' claims ',
            (claimable / 1 ether).toString(),
            ' KONG.","image":"',
            image,
            '","attributes":[{"trait_type":"Tier","value":',
            uint256(tier).toString(),
            '},{"trait_type":"Claimable KONG","value":',
            (claimable / 1 ether).toString(),
            '},{"trait_type":"Share","value":',
            tokenId.toString(),
            '}]}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    // ERC721Royalty + ERC721 both define supportsInterface; resolve it.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
