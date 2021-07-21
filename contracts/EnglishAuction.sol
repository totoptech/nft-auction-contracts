// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract EnglishAuction is IERC721Receiver {
    using SafeMath for uint256;

    struct Order {
        // Order ID
        bytes32 id;
        // Owner of the NFT
        address seller;
        // NFT registry address
        address nftAddress;
        // NFT ID
        uint256 assetId;
        // Acceptable token
        address acceptableToken;
        // Price for the published item
        uint256 startingPrice;
        // Timeinterval for the next bid
        uint256 timeInterval;
    }

    struct Bid {
        // Bid id
        bytes32 id;
        // Bidder address
        address bidder;
        // Acceptable token
        address acceptableToken;
        // Price for the bid
        uint256 price;
        // Bid time
        uint256 bidTime;
    }

    // From ERC721 registry assetId to Order
    mapping(address => mapping(uint256 => Order)) orders;

    // From ERC721 registry assetId to Bid
    mapping(address => mapping(uint256 => Bid)) bids;

    event OrderCreated(
        bytes32 id,
        address seller,
        address nftAddress,
        uint256 assetId,
        address acceptableToken,
        uint256 startingPrice,
        uint256 timeInterval
    );

    event BidCreated(
        bytes32 id,
        address seller,
        address nftAddress,
        uint256 assetId,
        address bidder,
        address acceptableToken,
        uint256 price,
        uint256 bidTime
    );

    event BidAccepted(bytes32 id);

    constructor() {}

    // 721 Interface
    bytes4 public constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /**
     * Create a new order
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     * acceptableToken - Token can be accepted
     * startingPrice - Starting token amount
     * timeInterval - Maximum duration for the next bid
     */
    function createOrder(
        address _nftAddress,
        uint256 _assetId,
        address _acceptableToken,
        uint256 _startingPrice,
        uint256 _timeInterval
    ) public returns (bytes32) {
        return
            _createOrder(
                _nftAddress,
                _assetId,
                _acceptableToken,
                _startingPrice,
                _timeInterval
            );
    }

    /**
     * Create a new bid
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     * tokenAddress - Bid token address
     * price - Bid price
     */
    function createBid(
        address _nftAddress,
        uint256 _assetId,
        address _tokenAddress,
        uint256 _price
    ) public payable returns (bytes32) {
        return _createBid(_nftAddress, _assetId, _tokenAddress, _price);
    }

    /**
     * Accept the last bid
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     */
    function acceptBid(address _nftAddress, uint256 _assetId) public {
        // Check order validity
        Order memory order = _getValidOrder(_nftAddress, _assetId);

        Bid memory bid = bids[_nftAddress][_assetId];

        delete bids[_nftAddress][_assetId];

        //Escrow to the seller
        if (order.acceptableToken == address(0)) {
            // It means that it is Ether
            payable(order.seller).transfer(bid.price);
        } else {
            IERC20 acceptableToken = IERC20(order.acceptableToken);
            acceptableToken.transfer(order.seller, bid.price);
        }

        _executeOrder(_nftAddress, _assetId, bid.bidder);

        emit BidAccepted(bid.id);
    }

    /**
     * Cancel the bid
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     */
    function _cancelBid(address _nftAddress, uint256 _assetId) internal {
        Bid memory bid = bids[_nftAddress][_assetId];
        delete bids[_nftAddress][_assetId];
        if (bid.acceptableToken == address(0)) {
            payable(bid.bidder).transfer(bid.price);
        } else {
            IERC20 acceptableToken = IERC20(bid.acceptableToken);
            acceptableToken.transfer(bid.bidder, bid.price);
        }
    }

    /**
     * Load the order by nftAddress and assetId
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     */
    function _getValidOrder(address _nftAddress, uint256 _assetId)
        internal
        returns (Order memory order)
    {
        order = orders[_nftAddress][_assetId];
        require(order.id != 0, "Order does not exist");
    }

    /**
     * Execute the order
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     * buyer - Buyer address
     */
    function _executeOrder(
        address _nftAddress,
        uint256 _assetId,
        address _buyer
    ) internal {
        // Transfer NFT asset
        IERC721(_nftAddress).safeTransferFrom(address(this), _buyer, _assetId);

        delete orders[_nftAddress][_assetId];
    }

    /**
     * Create a new order
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     * acceptableToken - Token can be accepted
     * startingPrice - Starting token amount
     * timeInterval - Maximum duration for the next bid
     */
    function _createOrder(
        address _nftAddress,
        uint256 _assetId,
        address _acceptableToken,
        uint256 _startingPrice,
        uint256 _timeInterval
    ) internal returns (bytes32) {
        // Check nft registry
        IERC721 nftRegistry = _requireERC721(_nftAddress);

        // Check order creator is the asset owner
        address assetOwner = nftRegistry.ownerOf(_assetId);

        require(
            assetOwner == msg.sender,
            "Only the asset owner can create an order"
        );

        require(_startingPrice > 0, "Price should be greater than 0");

        // Get NFT asset from seller
        nftRegistry.safeTransferFrom(assetOwner, address(this), _assetId);

        // Create the orderId
        bytes32 orderId = keccak256(
            abi.encodePacked(
                block.timestamp,
                assetOwner,
                _nftAddress,
                _assetId,
                _acceptableToken,
                _startingPrice,
                _timeInterval
            )
        );

        // Save order
        orders[_nftAddress][_assetId] = Order({
            id: orderId,
            seller: assetOwner,
            nftAddress: _nftAddress,
            assetId: _assetId,
            acceptableToken: _acceptableToken,
            startingPrice: _startingPrice,
            timeInterval: _timeInterval
        });

        emit OrderCreated(
            orderId,
            assetOwner,
            _nftAddress,
            _assetId,
            _acceptableToken,
            _startingPrice,
            _timeInterval
        );

        return orderId;
    }

    /**
     * Create a new bid
     * nftAddress - Non fungible contract address
     * assetId - ID of the published NFT
     * tokenAddress - Bid token address
     * price - Bid price
     */
    function _createBid(
        address _nftAddress,
        uint256 _assetId,
        address _tokenAddress,
        uint256 _price
    ) internal returns (bytes32) {
        Order memory order = _getValidOrder(_nftAddress, _assetId);
        Bid memory previousBid = bids[_nftAddress][_assetId];

        if (previousBid.id != 0) {
            require(
                previousBid.bidTime + order.timeInterval >= block.timestamp,
                "Bid time exceeded"
            );
            require(
                _price > previousBid.price,
                "Bid price should be higher than last bid"
            );

            _cancelBid(_nftAddress, _assetId);
        } else {
            require(
                order.acceptableToken == _tokenAddress,
                "Cannot acceptable token"
            );

            if (_tokenAddress == address(0)) {
                // It means that the token is Ether.
                require(
                    msg.value >= order.startingPrice,
                    "Bid price should be equal or greater than the starting price"
                );
            } else {
                require(
                    _price >= order.startingPrice,
                    "Bid price should be equal or greater than the starting price"
                );
            }
        }

        uint256 price = _price;

        if (order.acceptableToken == address(0)) {
            price = msg.value;
        } else {
            IERC20 acceptableToken = IERC20(order.acceptableToken);
            acceptableToken.transferFrom(msg.sender, address(this), price);
        }

        bytes32 bidId = keccak256(
            abi.encodePacked(
                block.timestamp,
                msg.sender,
                order.acceptableToken,
                price
            )
        );

        // Save Bid
        bids[_nftAddress][_assetId] = Bid({
            id: bidId,
            bidder: msg.sender,
            acceptableToken: order.acceptableToken,
            price: price,
            bidTime: block.timestamp
        });

        emit BidCreated(
            bidId,
            order.seller,
            _nftAddress,
            _assetId,
            msg.sender,
            order.acceptableToken,
            price,
            block.timestamp
        );

        return bidId;
    }

    function _requireERC721(address _nftAddress)
        internal
        view
        returns (IERC721)
    {
        require(
            IERC721(_nftAddress).supportsInterface(_INTERFACE_ID_ERC721),
            "The NFT contract has an invalid ERC721 implementation"
        );

        return IERC721(_nftAddress);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
