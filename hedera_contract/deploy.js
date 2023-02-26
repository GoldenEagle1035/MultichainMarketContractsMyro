const {
    Client,
    AccountId,
    PrivateKey,
    ContractCreateFlow,
} = require('@hashgraph/sdk');

require('dotenv').config();
const fs = require('fs');

// Get operator from .env file
const operatorKey = PrivateKey.fromString(process.env.PRIVATE_KEY);
const operatorId = AccountId.fromString(process.env.ACCOUNT_ID);

const client = Client.forTestnet().setOperator(operatorId, operatorKey);
 
// Marketplace Instance
async function contractDeployFcn(bytecode, gasLim, feePercent) {
	const contractCreateTx = new ContractCreateFlow().setBytecode(bytecode).setGas(gasLim).setConstructorParams(new Uint(feePercent));
	const contractCreateSubmit = await contractCreateTx.execute(client);
	const contractCreateRx = await contractCreateSubmit.getReceipt(client);
	const contractId = contractCreateRx.contractId;
	const contractAddress = contractId.toSolidityAddress();
	return [contractId, contractAddress];
}

// NFT Instance
async function contractDeployFcn(bytecode, gasLim) {
	const contractCreateTx = new ContractCreateFlow().setBytecode(bytecode).setGas(gasLim);
	const contractCreateSubmit = await contractCreateTx.execute(client);
	const contractCreateRx = await contractCreateSubmit.getReceipt(client);
	const ncontractId = contractCreateRx.ncontractId;
	const ncontractAddress = ncontractId.toSolidityAddress();
	return [ncontractId, ncontractAddress];
}

const main = async () => {

	// Read the bytecode of the contract from the compiled artifacts
	const json = JSON.parse(fs.readFileSync('./contracts/Marketplace.json'));
	const njson = JSON.parse(fs.readFileSync('./contracts/NFT.json'));

    const contractBytecode = json.bytecode;
	const ncontractBytecode = njson.bytecode;
	
	console.log('\n- Deploying contract...');
	const gasLimit = 1000000;
    const feePercent = 1;

	// Deploy the contracts
	const [contractId, contractAddress] = await contractDeployFcn(contractBytecode, gasLimit, feePercent);
	const [ncontractId, ncontractAddress] = await contractDeployFcn(ncontractBytecode, gasLimit);
	
	console.log(` Marketplace Contract created with ID: ${contractId} / ${contractAddress}`);
	console.log(` Marketplace Contract created with ID: ${ncontractId} / ${ncontractAddress}`);
	
};

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
