const { expect } = require("chai");
const { expectRevert } = require("@openzeppelin/test-helpers");

const EnglishAuction = artifacts.require("EnglishAuction");
const SimpleNFT = artifacts.require("SimpleNFT");
const SimpleToken = artifacts.require("SimpleToken");

contract("EnglishAuction", (accounts) => {
    const nftName = "SimpleNFT";
    const nftSymbol = "NFT";
    const nftBaseURI = "https://example.com/token/";
    const nftAssetID = 0;

    const startingPrice = 100;
    const timeInterval = 100000;

    const bidPrice = 200;
    const bidPrice2 = 50;

    let englishAuctionInstance;
    let simpleNFTInstance;
    let simpleTokenInstance;

    const creator = accounts[0];
    const seller = accounts[1];
    const bidder = accounts[2];
    const minter = accounts[3];

    describe("init", async () => {
        beforeEach(async () => {
            simpleTokenInstance = await SimpleToken.new({ from: bidder });
            englishAuctionInstance = await EnglishAuction.new({
                from: creator,
            });

            // Minting NFT
            simpleNFTInstance = await SimpleNFT.new(
                nftName,
                nftSymbol,
                nftBaseURI,
                {
                    from: minter,
                }
            );
            await simpleNFTInstance.mint(seller, {
                from: minter,
            });
        });

        it("should place an order without error", async () => {
            await simpleNFTInstance.approve(
                englishAuctionInstance.address,
                nftAssetID,
                { from: seller }
            );

            await englishAuctionInstance.createOrder(
                simpleNFTInstance.address,
                nftAssetID,
                simpleTokenInstance.address,
                startingPrice,
                timeInterval,
                { from: seller }
            );

            const currentNFTOwner = await simpleNFTInstance.ownerOf(nftAssetID);

            expect(currentNFTOwner).to.equal(englishAuctionInstance.address);
        });

        describe("after placing order", async () => {
            beforeEach(async () => {
                // Place order
                await simpleNFTInstance.approve(
                    englishAuctionInstance.address,
                    nftAssetID,
                    { from: seller }
                );

                await englishAuctionInstance.createOrder(
                    simpleNFTInstance.address,
                    nftAssetID,
                    simpleTokenInstance.address,
                    startingPrice,
                    timeInterval,
                    { from: seller }
                );
            });

            it("should get an error when bid amount is lower", async () => {
                await simpleTokenInstance.approve(
                    englishAuctionInstance.address,
                    bidPrice2,
                    { from: bidder }
                );

                await expectRevert(
                    englishAuctionInstance.createBid(
                        simpleNFTInstance.address,
                        nftAssetID,
                        simpleTokenInstance.address,
                        bidPrice2,
                        { from: bidder }
                    ),
                    "Bid price should be equal or greater than the starting price"
                );
            });

            it("should place a bid without error", async () => {
                await simpleTokenInstance.approve(
                    englishAuctionInstance.address,
                    bidPrice,
                    { from: bidder }
                );

                await englishAuctionInstance.createBid(
                    simpleNFTInstance.address,
                    nftAssetID,
                    simpleTokenInstance.address,
                    bidPrice,
                    { from: bidder }
                );

                const auctionContractBalance =
                    await simpleTokenInstance.balanceOf(
                        englishAuctionInstance.address
                    );

                expect(auctionContractBalance.toNumber()).to.equal(bidPrice);
            });

            describe("after placing bid", async () => {
                beforeEach(async () => {
                    // Place bid
                    await simpleTokenInstance.approve(
                        englishAuctionInstance.address,
                        bidPrice,
                        { from: bidder }
                    );

                    await englishAuctionInstance.createBid(
                        simpleNFTInstance.address,
                        nftAssetID,
                        simpleTokenInstance.address,
                        bidPrice,
                        { from: bidder }
                    );
                });

                it("should accept order without error", async () => {
                    await englishAuctionInstance.acceptBid(
                        simpleNFTInstance.address,
                        nftAssetID,
                        {
                            from: seller,
                        }
                    );

                    const currentNFTOwner = await simpleNFTInstance.ownerOf(
                        nftAssetID
                    );

                    expect(currentNFTOwner).to.equal(bidder);

                    const sellerBalance = await simpleTokenInstance.balanceOf(
                        seller
                    );

                    expect(sellerBalance.toNumber()).to.equal(bidPrice);
                });
            });
        });
    });
});
