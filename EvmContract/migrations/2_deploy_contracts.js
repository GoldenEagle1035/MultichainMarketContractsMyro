const HyperXNFTFactory = artifacts.require("HyperXNFTFactory");
const ContractInterface721 = artifacts.require("ContractInterface721");
const ContractInterface1155 = artifacts.require("ContractInterface1155");
const ERC721Tradable = artifacts.require("ERC721Tradable");
const ERC1155Tradable = artifacts.require("ERC1155Tradable");

const WBUSD = artifacts.require("WBUSD");
const WHyperXToken = artifacts.require("WHyperXToken");
const CustomToken = artifacts.require("CustomToken");

module.exports = async function(deployer) {
  let intf;

  // await deployer.deploy(ERC721Tradable, "My ERC721 NFT Test", "NENT7", "https://baseuri/", "0x0000000000000000000000000000000000000000");
  // const instManage = await ERC721Tradable.deployed();
  // console.log("ERC721Tradable address: ", instManage.address);

  // await deployer.deploy(ERC1155Tradable, "My ERC1155 NFT Test", "NENT1", "test-uri", "0x0000000000000000000000000000000000000000");
  // const instManage2 = await ERC1155Tradable.deployed();
  // console.log("ERC1155Tradable address: ", instManage2.address);

  await deployer.deploy(ContractInterface721);
  let intf1 = await ContractInterface721.deployed();
  console.log("ContractInterface721 address: ", intf1.address);

  await deployer.deploy(ContractInterface1155);
  let intf2 = await ContractInterface1155.deployed();
  console.log("ContractInterface1155 address: ", intf2.address);

  await deployer.deploy(HyperXNFTFactory, intf1.address, intf2.address);
  intf = await HyperXNFTFactory.deployed();
  console.log("HyperXNFTFactory address: ", intf.address);

  await deployer.deploy(WBUSD);
  intf = await WBUSD.deployed();
  console.log("WBUSD address: ", intf.address);

  await deployer.deploy(WHyperXToken);
  intf = await WHyperXToken.deployed();
  console.log("WHyperXToken address: ", intf.address);

  await deployer.deploy(CustomToken);
  intf = await CustomToken.deployed();
  console.log("CustomToken address: ", intf.address);
};
