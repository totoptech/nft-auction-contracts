const SimpleToken = artifacts.require("SimpleToken");
const SimpleNFT = artifacts.require("SimpleNFT");
const EnglishAuction = artifacts.require("EnglishAuction");

module.exports = function (deployer) {
    deployer.deploy(SimpleToken).then(() =>
        deployer
            .deploy(SimpleNFT, "SimpleNFT", "SNT", "https://example.com/token/")
            .then(() => {
                return deployer.deploy(EnglishAuction);
            })
    );
};
