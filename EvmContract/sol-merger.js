const { merge } = require('sol-merger');
const fs = require('fs');

(async () => {
    // Get the merged code as a string
    // const mergedCode = await merge("./contracts/HyperXNFTCollection.sol");
    // // Print it out or write it to a file etc.
    // console.log(mergedCode);
    // await fs.writeFileSync('./contracts/HyperXNFTCollection-in-one.sol', mergedCode);

	let mergedCode2;
    //Get the merged code as a string
    mergedCode2 = await merge("./contracts/HyperXNFTFactory.sol");
    await fs.writeFileSync('../out/HyperXNFTFactoryAll.sol', mergedCode2);

    mergedCode2 = await merge("./contracts/ContractInterface721.sol");
    await fs.writeFileSync('../out/ContractInterface721All.sol', mergedCode2);

    mergedCode2 = await merge("./contracts/ContractInterface1155.sol");
    await fs.writeFileSync('../out/ContractInterface1155All.sol', mergedCode2);

    mergedCode2 = await merge("./contracts/WBUSD.sol");
    await fs.writeFileSync('../out/WBUSDAll.sol', mergedCode2);
}) ();
