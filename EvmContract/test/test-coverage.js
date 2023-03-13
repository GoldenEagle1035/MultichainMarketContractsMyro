var ass = require('assert');

const ERC721Tradable = artifacts.require("ERC721Tradable");
const ERC1155Tradable = artifacts.require("ERC1155Tradable");
const HyperXNFTFactory = artifacts.require("HyperXNFTFactory");

contract("contract test", async accounts => {
    let ERC721Inst;
    let ERC1155Inst;
    let HyperXNFTFactoryInst;
    before(async () => {
        ERC721Inst = await ERC721Tradable.deployed();
        ERC1155Inst = await ERC1155Tradable.deployed();
        HyperXNFTFactoryInst = await HyperXNFTFactory.deployed();
    })

    it("account log", () => {
        console.log("accounts: ", accounts);
    });

    it("ERC721 supportInterface", async () => {
        let iid = await ERC721Inst.supportsInterface("0x80ac58cd");
        ass.equal(iid, true);
        iid = await ERC721Inst.supportsInterface("0xd9b67a26");
        ass.equal(iid, false);
    })

    it("ERC1155 supportInterface", async () => {
        let iid = await ERC1155Inst.supportsInterface("0xd9b67a26");
        ass.equal(iid, true);
        iid = await ERC1155Inst.supportsInterface("0x80ac58cd");
        ass.equal(iid, false);
    })

    it("getDomainSeperator()", async () => {
        let iid = await ERC721Inst.getDomainSeperator();
        console.log(iid);
        iid = await ERC1155Inst.getDomainSeperator();
        console.log(iid);
        console.log("chain id:", (await ERC721Inst.getChainId()).toNumber());
    })

    it("HyperXNFTFactoryInst setFactoryContract", async () => {
        let tx = await ERC721Inst.setFactoryContract(HyperXNFTFactory.address);
        tx = await ERC1155Inst.setFactoryContract(HyperXNFTFactory.address);

        tx = ERC721Inst.setFactoryContract(HyperXNFTFactory.address);
        let vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = ERC1155Inst.setFactoryContract(HyperXNFTFactory.address);
        vv = await tx.catch(e => e.message);
        console.log(vv);

        ass.equal(await ERC721Inst.factory(), HyperXNFTFactoryInst.address);
        ass.equal(await ERC1155Inst.factory(), HyperXNFTFactoryInst.address);
    })

    // it("ERC721, ERC1155 transfer ownership to the factory", async () => {
    //     await ERC721Inst.transferOwnership(HyperXNFTFactoryInst.address);
    //     await ERC1155Inst.transferOwnership(HyperXNFTFactoryInst.address);

    //     ass.equal(await ERC721Inst.owner(), HyperXNFTFactoryInst.address);
    //     ass.equal(await ERC1155Inst.owner(), HyperXNFTFactoryInst.address);
    // })

    it("HyperXNFTFactoryInst creator permission", async () => {
        await HyperXNFTFactoryInst.startPendingCreator(accounts[8], true);
        let tx = HyperXNFTFactoryInst.endPendingCreator(accounts[8]);
        let vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = HyperXNFTFactoryInst.startPendingCreator(accounts[8], true);
        vv = await tx.catch(e => e.message);
        console.log(vv);

        await new Promise(r => setTimeout(r, 4000));

        await HyperXNFTFactoryInst.endPendingCreator(accounts[8]);
        console.log("accounts[8]-%s as a creator", accounts[8]);
    })

    it("HyperXNFTFactoryInst createCollection", async () => {
        let tx = await HyperXNFTFactoryInst.createNewCollection(0, "New collection 721 added", "NCA721", "https://implicit721", {from: accounts[8]});
        // console.log(tx);
        // let i;
        // for (i = 0; i < tx.receipt.logs.length; i ++) {
        //     console.log(tx.receipt.logs[i]);
        //     if (tx.receipt.logs[i].event == 'NewCollectionCreated') {
        //         console.log(tx.receipt.logs[i].args.collectionType.toString());
        //     }
        // }

        tx = HyperXNFTFactoryInst.createNewCollection(1, "New collection 1155 added", "NCA1155", "https://implicit1155", {from: accounts[7]});
        let vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = await HyperXNFTFactoryInst.createNewCollection(1, "New collection 1155 added", "NCA1155", "https://implicit1155", {from: accounts[8]});

        // for (i = 0; i < tx.receipt.logs.length; i ++) {
        //     console.log(tx.receipt.logs[i]);
        //     if (tx.receipt.logs[i].event == 'NewCollectionCreated') {
        //         console.log(tx.receipt.logs[i].args.collectionType.toString());
        //     }
        // }

        tx = HyperXNFTFactoryInst.createNewCollection(2, "New collection 1155 added", "NCA1155", "https://implicit1155", {from: accounts[8]});
        vv = await tx.catch(e => e.message);
        console.log(vv);
    })

    it("HyperXNFTFactoryInst addCollection", async () => {
        let tx = await HyperXNFTFactoryInst.addCollection(ERC721Inst.address);
        tx = HyperXNFTFactoryInst.addCollection(ERC721Inst.address, {from: accounts[7]});
        let vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = HyperXNFTFactoryInst.addCollection(ERC721Inst.address, {from: accounts[8]});
        vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = await HyperXNFTFactoryInst.addCollection(ERC1155Inst.address, {from: accounts[8]});
        tx = HyperXNFTFactoryInst.addCollection(ERC1155Inst.address, {from: accounts[7]});
        vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = HyperXNFTFactoryInst.addCollection(ERC1155Inst.address, {from: accounts[8]});
        vv = await tx.catch(e => e.message);
        console.log(vv);

        tx = HyperXNFTFactoryInst.addCollection(accounts[2], {from: accounts[8]});
        vv = await tx.catch(e => e.message);
        console.log(vv);
    })

    it("HyperXNFTFactoryInst collections", async () => {
        let cols = await HyperXNFTFactoryInst.getCollections();
        console.log("collections registered to the factory");
        console.log(cols);
    })
})
