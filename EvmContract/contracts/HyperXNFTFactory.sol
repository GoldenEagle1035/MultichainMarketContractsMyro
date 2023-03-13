// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./IHyperXNFTFactory.sol";
import "./ContractInterface.sol";

contract HyperXNFTFactory is IHyperXNFTFactory, Ownable, ReentrancyGuard {
    using Address for address;

    struct HyperXNFTSale {
        uint256 saleId;
        address creator;
        address seller;
        address sc;
        uint256 tokenId;
        uint256 copy;
        uint256 payment;
        uint256 basePrice;
        uint256 method;
        uint256 startTime;
        uint256 endTime;
        uint256 feeRatio;
        uint256 royaltyRatio;
    }

    struct BookInfo {
        address user;
        uint256 totalPrice;
        uint256 serviceFee;
    }

    /**
     * delay period to add a creator to the list
     */
    uint256 public DELAY_PERIOD = 3 seconds;

    /**
     * deployer for single/multiple NFT collection
     */
    address private singleDeployer;
    address private multipleDeployer;

    /**
     * array of collection addresses including ERC721 and ERC1155
     */
    address[] private collections;
    /**
     * check if the collection has already been added to this factory
     */
    mapping(address => bool) collectionOccupation;

    /**
     * token address for payment
     */
    address[] private paymentTokens;

    /**
     * check if it is the creator permitted by owner(admin)
     */
    mapping(address => bool) private creators;
    /**
     * epoch timestamp of starting the process that permits one account to be a creator
     */
    mapping(address => uint256) private pendingTime;
    /**
     * pending value that presents the creator is enabled/disabled by true/false
     */
    mapping(address => bool) private pendingValue;

    /**
     * pending value that presents the creator is enabled/disabled by true/false
     */
    mapping(uint256 => BookInfo[]) private bookInfo;

    /**
     * default fee value set by owner of the contract, defaultFeeRatio / 10000 is the real ratio.
     */
    uint256 public defaultFeeRatio;

    /**
     * default royalty value set by owner of the contract, defaultRoyaltyRatio / 10000 is the real ratio.
     */
    uint256 public defaultRoyaltyRatio;

    /**
     * dev address
     */
    address public devAddress;

    /**
     * sale list by its created index
     */
    mapping(uint256 => HyperXNFTSale) saleList;

    /**
     * sale list count or future index to be created
     */
    uint256 public saleCount;

    /**
     * event that marks the creator has been permitted by an owner(admin)
     */
    event SetCreatorForFactory(address account, bool set);

    /**
     * event when an owner sets default fee ratio
     */
    event SetDefaultFeeRatio(address owner, uint256 newFeeRatio);

    /**
     * event when an owner sets default royalty ratio
     */
    event SetDefaultRoyaltyRatio(address owner, uint256 newRoyaltyRatio);

    /**
     * event when a new payment token set
     */
    event PaymentTokenSet(uint256 id, address indexed tokenAddress);

    /**
     * event when a new ERC721 contract is created.
     * Do not remove this event even if it is not used.
     */
    event CreatedERC721TradableContract(address indexed factory, address indexed newContract);

    /**
     * event when a new ERC1155 contract is created.
     * Do not remove this event even if it is not used.
     */
    event CreatedERC1155TradableContract(address indexed factory, address indexed newContract);

    /**
     * event when an seller lists his/her token on sale
     */

    event ListedOnSale(
        uint256 saleId,
        HyperXNFTSale saleInfo
    );

    /**
     * event when a seller cancels his sale
     */
    event RemoveFromSale(
        uint256 saleId,
        HyperXNFTSale saleInfo
    );

    /**
     * event when a user makes an offer for unlisted NFTs
     */

    event MakeOffer(
        address indexed user,
        uint256 saleId,
        HyperXNFTSale ti
    );

    /**
     * event when a user accepts an offer
     */

    event AcceptOffer(
        address indexed winner,
        uint256 saleId,
        HyperXNFTSale ti
    );

    /**
     * event when a user makes an offer for fixed-price sale
     */
    event Buy(
        address indexed user,
        uint256 saleId,
        HyperXNFTSale saleInfo
    );

    /**
     * event when a user places a bid for timed-auction sale
     */
    event PlaceBid(
        address indexed user,
        uint256 bidPrice,
        uint256 saleId,
        HyperXNFTSale saleInfo
    );

    /**
     * event when timed-auction times out
     */
    event AuctionResult(
        address indexed winner,
        uint256 totalPrice,
        uint256 serviceFee,
        uint256 saleId,
        HyperXNFTSale saleInfo
    );

    /**
     * event when a trade is successfully made.
     */

    event Trade(
        uint256 saleId,
        HyperXNFTSale sale,
        uint256 timestamp,
        uint256 paySeller,
        address owner,
        address winner,
        uint256 fee,
        uint256 royalty,
        address devAddress,
        uint256 devFee
    );

    /**
     * event when deployers are updated
     */
    event UpdateDeployers(
        address indexed singleCollectionDeployer,
        address indexed multipleCollectionDeployer
    );

    /**
     * event when NFT are transferred
     */
    event TransferNFTs(
        address from,
        address to,
        address collection,
        uint256[] ids,
        uint256[] amounts
    );

    /**
     * this modifier restricts some privileged action
     */
    modifier creatorOnly() {
        address ms = msg.sender;
        require(
            ms == owner() || creators[ms] == true,
            "neither owner nor creator"
        );
        _;
    }

    /**
     * constructor of the factory does not have parameters
     */
    constructor(
        address singleCollectionDeployer,
        address multipleCollectionDeployer
    ) {
        paymentTokens.push(address(0)); // native currency
        
        setDefaultFeeRatio(250);
        setDefaultRoyaltyRatio(300);
        updateDeployers(singleCollectionDeployer, multipleCollectionDeployer);
    }

    /**
     * @dev this function updates the deployers for ERC721, ERC1155
     * @param singleCollectionDeployer - deployer for ERC721
     * @param multipleCollectionDeployer - deployer for ERC1155
     */

    function updateDeployers(
        address singleCollectionDeployer,
        address multipleCollectionDeployer
    ) public onlyOwner {
        singleDeployer = singleCollectionDeployer;
        multipleDeployer = multipleCollectionDeployer;

        emit UpdateDeployers(singleCollectionDeployer, multipleCollectionDeployer);
    }

    /**
     * This function modifies or adds a new payment token
     */
    function setPaymentToken(uint256 tId, address tokenAddr) public onlyOwner {
        // IERC165(tokenAddr).supportsInterface(type(IERC20).interfaceId);
        require(tokenAddr != address(0), "null address for payment token");

        if (tId >= paymentTokens.length ) {
            tId = paymentTokens.length;
            paymentTokens.push(tokenAddr);
        } else {
            require(tId < paymentTokens.length, "invalid payment token id");
            paymentTokens[tId] = tokenAddr;
        }

        emit PaymentTokenSet(tId, tokenAddr);
    }

    /**
     * This function gets token addresses for payment
     */
    function getPaymentToken() public view returns (address[] memory) {
        return paymentTokens;
    }

    /**
     * start the process of adding a creator to be enabled/disabled
     */
    function startPendingCreator(address account, bool set) external onlyOwner {
        require(pendingTime[account] == 0);

        pendingTime[account] = block.timestamp;
        pendingValue[account] = set;
    }

    /**
     * end the process of adding a creator to be enabled/disabled
     */
    function endPendingCreator(address account) external onlyOwner {
        require((pendingTime[account] + DELAY_PERIOD) < block.timestamp);

        bool curVal = pendingValue[account];
        creators[account] = curVal;
        pendingTime[account] = 0;

        emit SetCreatorForFactory(account, curVal);
    }

    /**
     * set developer address
     */
    function setDevAddr(address addr) public onlyOwner {
        devAddress = addr;
    }

    /**
     * @dev this function creates a new collection of ERC721, ERC1155 to the factory
     * @param collectionType - ERC721 = 0, ERC1155 = 1
     * @param _name - collection name
     * @param _symbol - collection symbol
     * @param _uri - base uri of NFT token metadata
     */
    function createNewCollection(
        IHyperXNFTFactory.CollectionType collectionType,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) external creatorOnly override returns (address) {
        if (collectionType == IHyperXNFTFactory.CollectionType.ERC721) {
            // create a new ERC721 contract and returns its address
            address newContract = IContractInterface721(singleDeployer).createContract(_name, _symbol, _uri, address(this));

            require(collectionOccupation[newContract] == false);

            collections.push(newContract);
            collectionOccupation[newContract] = true;

            Ownable(newContract).transferOwnership(msg.sender);

            return newContract;
        } else if (collectionType == IHyperXNFTFactory.CollectionType.ERC1155) {
            // create a new ERC1155 contract and returns its address
            address newContract = IContractInterface1155(multipleDeployer).createContract(_name, _symbol, _uri, address(this));

            require(collectionOccupation[newContract] == false);

            collections.push(newContract);
            collectionOccupation[newContract] = true;

            Ownable(newContract).transferOwnership(msg.sender);

            return newContract;
        } else revert("Unknown collection contract");
    }

    /**
     * @dev this function adds a collection of ERC721, ERC1155 to the factory
     * @param from - address of NFT collection contract
     */
    function addCollection(address from) external creatorOnly override {
        require(from.isContract());

        if (IERC165(from).supportsInterface(type(IERC721).interfaceId)) {
            require(collectionOccupation[from] == false);

            collections.push(from);
            collectionOccupation[from] = true;

            emit CollectionAdded(IHyperXNFTFactory.CollectionType.ERC721, from);
        } else if (
            IERC165(from).supportsInterface(type(IERC1155).interfaceId)
        ) {
            require(collectionOccupation[from] == false);

            collections.push(from);
            collectionOccupation[from] = true;

            emit CollectionAdded(
                IHyperXNFTFactory.CollectionType.ERC1155,
                from
            );
        } else {
            revert("Error adding unknown NFT collection");
        }
    }

    /**
     * @dev this function transfers NFTs of 'sc' from account 'from' to account 'to' for token ids 'ids'
     * @param sc - address of NFT collection contract
     * @param from - owner of NFTs at the moment
     * @param to - future owner of NFTs
     * @param ids - array of token id to be transferred
     * @param amounts - array of token amount to be transferred
     */
    function transferNFT(
        address sc,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        require(collectionOccupation[sc] == true);

        if (IERC165(sc).supportsInterface(type(IERC721).interfaceId)) {
            // ERC721 transfer, amounts has no meaning in this case
            uint256 i;
            bytes memory nbytes = new bytes(0);
            for (i = 0; i < ids.length; i++) {
                IERC721(sc).safeTransferFrom(from, to, ids[i], nbytes);
            }
        } else if (IERC165(sc).supportsInterface(type(IERC1155).interfaceId)) {
            // ERC1155 transfer
            bytes memory nbytes = new bytes(0);
            IERC1155(sc).safeBatchTransferFrom(from, to, ids, amounts, nbytes);
        }

        emit TransferNFTs(from, to, sc, ids, amounts);
    }

    /**
     * @dev this function retrieves array of all collections registered to the factory
     */
    function getCollections()
        public
        view
        returns (address[] memory)
    {
        return collections;
    }

    /**
     * @dev this function sets default fee ratio.
     */
    function setDefaultFeeRatio(uint256 newFeeRatio) public onlyOwner {
        defaultFeeRatio = newFeeRatio;
        emit SetDefaultFeeRatio(owner(), newFeeRatio);
    }

    /**
     * @dev this function sets default royalty ratio.
     */
    function setDefaultRoyaltyRatio(uint256 newRoyaltyRatio) public onlyOwner {
        defaultRoyaltyRatio = newRoyaltyRatio;
        emit SetDefaultRoyaltyRatio(owner(), newRoyaltyRatio);
    }

    /**
     * @dev this function returns URI string by checking its ERC721 or ERC1155 type.
     */
    function getURIString(address sc, uint256 tokenId)
        internal
        view
        returns (string memory uri, uint256 sc_type)
    {
        if (IERC165(sc).supportsInterface(type(IERC721).interfaceId)) {
            uri = IContractInfoWrapper(sc).tokenURI(tokenId);
            sc_type = 1;
        } else if (IERC165(sc).supportsInterface(type(IERC1155).interfaceId)) {
            uri = IContractInfoWrapper(sc).uri(tokenId);
            sc_type = 2;
        } else sc_type = 0;
    }

    /**
     * @dev this function sets default royalty ratio.
     * @param sc - address of NFT collection contract
     * @param tokenId - token index in 'sc'
     * @param payment - payment method for buyer/bidder/offerer/auctioner, 0: BNB, 1: BUSD, 2: HyperX, ...
     * @param method - duration of sale in seconds
     * @param duration - duration of sale in seconds
     * @param basePrice - price in 'payment' coin
     * @param feeRatio - fee ratio (1/10000) for transaction
     * @param royaltyRatio - royalty ratio (1/10000) for transaction
     */
    function createSale(
        address sc,
        uint256 tokenId,
        uint256 payment,
        uint256 copy,
        uint256 method,
        uint256 duration,
        uint256 basePrice,
        uint256 feeRatio,
        uint256 royaltyRatio
    ) public {
        (, uint256 sc_type) = getURIString(sc, tokenId);
        address creator = address(0);

        if (sc_type == 1) {
            require(
                IERC721(sc).ownerOf(tokenId) == msg.sender,
                "not owner of the ERC721 token to be on sale"
            );
            require(copy == 1, "ERC721 token sale amount is not 1");
            creator = IContractInfoWrapper(sc).getCreator(tokenId);
        } else if (sc_type == 2) {
            uint256 bl = IERC1155(sc).balanceOf(msg.sender, tokenId);
            require(
                bl >= copy && copy > 0,
                "exceeded amount of ERC1155 token to be on sale"
            );
            creator = IContractInfoWrapper(sc).getCreator(tokenId);
        } else revert("Not supported NFT contract");

        uint256 curSaleIndex = saleCount;
        saleCount++;

        HyperXNFTSale storage hxns = saleList[curSaleIndex];

        hxns.saleId = curSaleIndex;

        hxns.creator = creator;
        hxns.seller = msg.sender;

        hxns.sc = sc;
        hxns.tokenId = tokenId;
        hxns.copy = copy;

        hxns.payment = payment;
        hxns.basePrice = basePrice;

        hxns.method = method;

        hxns.startTime = block.timestamp;
        hxns.endTime = block.timestamp + duration;

        hxns.feeRatio = (feeRatio == 0) ? defaultFeeRatio : feeRatio;
        hxns.royaltyRatio = (royaltyRatio == 0)
            ? defaultRoyaltyRatio
            : royaltyRatio;

        emit ListedOnSale(
            curSaleIndex,
            hxns
        );
    }

    /**
     * @dev this function removes an existing sale
     * @param saleId - index of the sale
     */
    function removeSale(uint256 saleId) external {
        HyperXNFTSale storage hxns = saleList[saleId];
        require(msg.sender == hxns.seller || msg.sender == owner(), "unprivileged remove");

        _removeSale(saleId);
    }

    /**
     * @dev this function removes an existing sale
     * @param saleId - index of the sale
     */
    function _removeSale(uint256 saleId) internal {
        HyperXNFTSale storage hxns = saleList[saleId];

        emit RemoveFromSale(
            saleId,
            hxns
        );
        
        hxns.seller = address(0);
    }

    /**
     * @dev this function sets default royalty ratio.
     * @param sc - address of NFT collection contract
     * @param tokenId - token index in 'sc'
     * @param payment - payment method for buyer/bidder/offerer/auctioner, 0: BNB, 1: BUSD, 2: HyperX, ...
     * @param duration - duration of sale in seconds
     * @param unitPrice - price in 'payment' coin
     */
    function makeOffer(
        address sc,
        uint256 tokenId,
        address owner,
        uint256 copy,
        uint256 payment,
        uint256 unitPrice,
        uint256 duration
    ) public payable nonReentrant{
        (, uint256 sc_type) = getURIString(sc, tokenId);
        address creator = address(0);

        if (sc_type == 1) {
            require(
                IERC721(sc).ownerOf(tokenId) == owner,
                "invalid owner of the ERC721 token to be offered"
            );
            require(copy == 1, "ERC721 token offer is not 1");
            creator = IContractInfoWrapper(sc).getCreator(tokenId);
        } else if (sc_type == 2) {
            uint256 bl = IERC1155(sc).balanceOf(owner, tokenId);
            require(
                bl >= copy && copy > 0,
                "exceeded amount of ERC1155 token to be offered"
            );
            creator = IContractInfoWrapper(sc).getCreator(tokenId);
        } else revert("Not supported NFT contract");

        require(msg.sender != owner, "Owner is not allowed to make an offer on his NFT");

        uint256 curSaleIndex = saleCount;
        saleCount++;

        HyperXNFTSale storage hxns = saleList[curSaleIndex];

        hxns.saleId = curSaleIndex;

        hxns.creator = creator;
        hxns.seller = owner;

        hxns.sc = sc;
        hxns.tokenId = tokenId;
        hxns.copy = copy;

        hxns.payment = payment;
        hxns.basePrice = unitPrice;

        hxns.method = 2; // 0: fixed price, 1: timed auction, 2: offer

        hxns.startTime = block.timestamp;
        hxns.endTime = block.timestamp + duration;

        hxns.feeRatio = defaultFeeRatio;
        hxns.royaltyRatio = defaultRoyaltyRatio;

        uint256 salePrice = hxns.copy * hxns.basePrice;
        uint256 serviceFee = salePrice * hxns.feeRatio / 10000;
        uint256 totalPay = salePrice + serviceFee;

        BookInfo[] storage bi = bookInfo[curSaleIndex];
        BookInfo memory newBI = BookInfo(msg.sender, salePrice, serviceFee);
        bi.push(newBI);

        if (hxns.payment == 0) {
            require(
                msg.value >= totalPay,
                "insufficient native currency to buy"
            );
            if (msg.value > totalPay) {
                address payable py = payable(msg.sender);
                py.transfer(msg.value - totalPay);
            }
        } else {
            IERC20 tokenInst = IERC20(paymentTokens[hxns.payment]);
            tokenInst.transferFrom(msg.sender, address(this), totalPay);
        }

        emit MakeOffer(
            newBI.user,
            curSaleIndex,
            hxns
        );
    }

    /**
     * @dev this function lets a buyer buy NFTs on sale
     * @param saleId - index of the sale
     */
    function buy(uint256 saleId) public payable nonReentrant {
        require(isSaleValid(saleId), "sale is not valid");

        HyperXNFTSale storage hxns = saleList[saleId];

        require(hxns.startTime <= block.timestamp, "sale not started yet");
        require(
            hxns.endTime <= hxns.startTime || hxns.endTime >= block.timestamp,
            "sale already ended"
        );
        require(hxns.method == 0, "offer not for fixed-price sale");
        require(msg.sender != hxns.seller, "Seller is not allowed to buy his NFT");

        uint256 salePrice = hxns.copy * hxns.basePrice;
        uint256 serviceFee = salePrice * hxns.feeRatio / 10000;
        uint256 totalPay = salePrice + serviceFee;

        if (hxns.payment == 0) {
            require(
                msg.value >= totalPay,
                "insufficient native currency to buy"
            );
            if (msg.value > totalPay) {
                address payable py = payable(msg.sender);
                py.transfer(msg.value - totalPay);
            }
        } else {
            IERC20 tokenInst = IERC20(paymentTokens[hxns.payment]);
            tokenInst.transferFrom(msg.sender, address(this), totalPay);
        }

        BookInfo[] storage bi = bookInfo[saleId];
        BookInfo memory newBI = BookInfo(msg.sender, salePrice, serviceFee);

        bi.push(newBI);

        emit Buy(msg.sender, saleId, hxns);

        trade(saleId, bi.length - 1);
    }

    /**
     * @dev this function places an bid from a user
     * @param saleId - index of the sale
     * @param price - index of the sale
     */
    function placeBid(uint256 saleId, uint256 price) public payable nonReentrant {
        require(isSaleValid(saleId), "sale is not valid");

        HyperXNFTSale storage hxns = saleList[saleId];

        require(hxns.startTime <= block.timestamp, "sale not started yet");
        require(
            hxns.endTime <= hxns.startTime || hxns.endTime >= block.timestamp,
            "sale already ended"
        );
        require(hxns.method == 1, "bid not for timed-auction sale");
        require(msg.sender != hxns.seller, "Seller is not allowed to place a bid on his NFT");

        uint256 startingPrice = hxns.copy * hxns.basePrice;
        uint256 bidPrice = hxns.copy * price;
        uint256 serviceFee = bidPrice * hxns.feeRatio / 10000;
        uint256 totalPay = bidPrice + serviceFee;

        BookInfo[] storage bi = bookInfo[saleId];
        require((bi.length == 0 && startingPrice < bidPrice) || bi[0].totalPrice < bidPrice, "bid price is not larger than the last bid's");

        if (hxns.payment == 0) {
            if (bi.length > 0) {
                address payable pyLast = payable(bi[0].user);
                pyLast.transfer(bi[0].totalPrice + bi[0].serviceFee);
            }
            if (msg.value > totalPay) {
                address payable py = payable(msg.sender);
                py.transfer(msg.value - totalPay);
            }
        } else {
            IERC20 tokenInst = IERC20(paymentTokens[hxns.payment]);
            if (bi.length > 0) {
                tokenInst.transfer(bi[0].user, bi[0].totalPrice + bi[0].serviceFee);
            }
            tokenInst.transferFrom(msg.sender, address(this), totalPay);
        }

        if (bi.length == 0)  {
            BookInfo memory newBI = BookInfo(msg.sender, bidPrice, serviceFee);
            bi.push(newBI);
        } else {
            bi[0].user = msg.sender;
            bi[0].totalPrice = bidPrice;
            bi[0].serviceFee = serviceFee;
        }

        emit PlaceBid(
            msg.sender,
            price,
            saleId,
            hxns
        );
    }

    /**
     * @dev this function puts an end to timed-auction sale
     * @param saleId - index of the sale of timed-auction
     */
    function finalizeAuction(uint256 saleId) public payable nonReentrant onlyOwner {
        require(isSaleValid(saleId), "sale is not valid");

        HyperXNFTSale storage hxns = saleList[saleId];

        require(hxns.startTime <= block.timestamp, "sale not started yet");
        // finalize timed-auction anytime by owner of this factory contract.
        require(hxns.method == 1, "bid not for timed-auction sale");

        BookInfo[] storage bi = bookInfo[saleId];

        // winning to the highest bid
        if (bi.length > 0) {
            uint256 loop;
            uint256 maxPrice = bi[0].totalPrice;
            uint256 bookId = 0;

            for (loop = 0; loop < bi.length; loop++) {
                BookInfo memory biItem = bi[loop];
                if (maxPrice < biItem.totalPrice) {
                    maxPrice = biItem.totalPrice;
                    bookId = loop;
                }
            }

            emit AuctionResult(
                bi[bookId].user,
                bi[bookId].totalPrice,
                bi[bookId].serviceFee,
                saleId,
                hxns
            );
            trade(saleId, bookId);
        } else {
            _removeSale(saleId);
        }
    }

    /**
     * @dev this function puts an end to offer sale
     * @param saleId - index of the sale of offer
     */
    function acceptOffer(uint256 saleId) public payable nonReentrant {
        require(isSaleValid(saleId), "sale is not valid");

        HyperXNFTSale storage hxns = saleList[saleId];

        require(hxns.startTime <= block.timestamp, "sale not started yet");
        require(hxns.method == 2, "not sale for offer");
        require(hxns.seller == msg.sender, "only seller can accept offer for his NFT");

        BookInfo[] storage bi = bookInfo[saleId];
        require(bi.length > 0, "nobody made an offer");

        // winning to the highest bid
        if (bi.length > 0) {
            emit AcceptOffer(
                bi[0].user,
                saleId,
                hxns
            );
            trade(saleId, 0);
        }
    }

    /**
     * @dev this function removes an offer
     * @param saleId - index of the sale of offer
     */
    function removeOffer(uint256 saleId) public payable nonReentrant {
        require(isSaleValid(saleId), "sale is not valid");

        HyperXNFTSale storage hxns = saleList[saleId];

        require(hxns.seller == msg.sender || owner() == msg.sender, "only seller can remove an offer");
        require(hxns.method == 2, "not sale for offer");

        BookInfo[] storage bi = bookInfo[saleId];

        if (bi.length > 0) {
            // failed offer, refund
            uint256 loop;
            for (loop = 0; loop < bi.length; loop ++) {
                BookInfo memory biItem = bi[loop];
                if (hxns.payment == 0) {
                    address payable py = payable(biItem.user);
                    py.transfer(biItem.totalPrice);
                } else {
                    IERC20 tokenInst = IERC20(paymentTokens[hxns.payment]);
                    tokenInst.transfer(
                        biItem.user,
                        biItem.totalPrice
                    );
                }
            }
        }

        _removeSale(saleId);
    }

    /**
     * @dev this function transfers NFTs from the seller to the buyer
     * @param saleId - index of the sale to be treated
     * @param bookId - index of the booked winner on a sale
     */

    function trade(uint256 saleId, uint256 bookId) internal {
        require(isSaleValid(saleId), "sale is not valid");

        HyperXNFTSale storage hxns = saleList[saleId];

        BookInfo[] storage bi = bookInfo[saleId];

        uint256 loop;
        for (loop = 0; loop < bi.length; loop++) {
            BookInfo memory biItem = bi[loop];

            if (loop == bookId) {
                // winning bid
                //fee policy
                uint256 fee = biItem.serviceFee;
                uint256 royalty = (hxns.royaltyRatio * biItem.totalPrice) /
                    10000;
                uint256 devFee = 0;
                if (devAddress != address(0)) {
                    devFee = (biItem.totalPrice * 30) / 10000;
                }

                uint256 pySeller = biItem.totalPrice - royalty - devFee;

                if (hxns.payment == 0) {
                    address payable py = payable(hxns.seller);
                    py.transfer(pySeller);

                    if (fee > 0) {
                        py = payable(owner());
                        py.transfer(fee);
                    }

                    if (royalty > 0) {
                        py = payable(hxns.creator);
                        py.transfer(royalty);
                    }

                    if (devFee > 0) {
                        py = payable(devAddress);
                        py.transfer(devFee);
                    }
                } else {
                    IERC20 tokenInst = IERC20(paymentTokens[hxns.payment]);
                    tokenInst.transfer(
                        hxns.seller,
                        pySeller
                    );

                    if (fee > 0) {
                        tokenInst.transfer(owner(), fee);
                    }

                    if (royalty > 0) {
                        tokenInst.transfer(
                            hxns.creator,
                            royalty
                        );
                    }

                    if (devFee > 0) {
                        tokenInst.transfer(
                            devAddress,
                            devFee
                        );
                    }
                }

                uint256[] memory ids = new uint256[](1);
                ids[0] = hxns.tokenId;
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = hxns.copy;

                transferNFT(hxns.sc, hxns.seller, biItem.user, ids, amounts);

                emit Trade(
                    saleId,
                    hxns,
                    block.timestamp,
                    pySeller,
                    owner(),
                    biItem.user,
                    fee,
                    royalty,
                    devAddress,
                    devFee
                );
            } else {
                // failed bid, refund
                if (hxns.payment == 0) {
                    address payable py = payable(biItem.user);
                    py.transfer(biItem.totalPrice);
                } else {
                    IERC20 tokenInst = IERC20(paymentTokens[hxns.payment]);
                    tokenInst.transfer(
                        biItem.user,
                        biItem.totalPrice
                    );
                }
            }
        }

        _removeSale(saleId);
    }

    /**
     * @dev this function returns all items on sale
     * @param startIdx - starting index in all items on sale
     * @param count - count to be retrieved, the returned array will be less items than count because some items are invalid
     */
    function getSaleInfo(uint256 startIdx, uint256 count)
        external
        view
        returns (HyperXNFTSale[] memory)
    {
        uint256 i;
        uint256 endIdx = startIdx + count;

        uint256 realCount = 0;
        for (i = startIdx; i < endIdx; i++) {
            if (i >= saleCount) break;

            if (!isSaleValid(i)) continue;

            realCount++;
        }

        HyperXNFTSale[] memory ret = new HyperXNFTSale[](realCount);

        uint256 nPos = 0;
        for (i = startIdx; i < endIdx; i++) {
            if (i >= saleCount) break;

            if (!isSaleValid(i)) continue;

            ret[nPos] = saleList[i];
            nPos++;
        }

        return ret;
    }

    /**
     * @dev this function returns validity of the sale
     * @param saleId - index of the sale
     */

    function isSaleValid(uint256 saleId) internal view returns (bool) {
        if (saleId >= saleCount) return false;
        HyperXNFTSale storage hxns = saleList[saleId];

        if (hxns.seller == address(0)) return false;
        return true;
    }
}
