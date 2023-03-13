// Migrations are an early feature. Currently, they're nothing more than this
// single deploy script that's invoked from the CLI, injecting a provider
// configured from the workspace's Anchor.toml.

const anchor = require("@project-serum/anchor");
const { SystemProgram, Keypair, PublicKey } = anchor.web3;
const { AccountLayout, TOKEN_PROGRAM_ID, Token } = require('@solana/spl-token');
const { IDL } = require('../target/types/marketplace');

const PROGRAM_ID = '9mQisfKUTdSWFdonYYbnA3Lnzks1bR3b3tHerHZAgByt';

module.exports = async function (provider) {
  // Configure client to use the provider.
  anchor.setProvider(provider);
  const program = new anchor.Program(IDL, new PublicKey(PROGRAM_ID), provider);

  let [vaultPDA, bumpVault] = await anchor.web3.PublicKey.findProgramAddress(
    [Buffer.from('rewards vault')],
    program.programId
  );
  
  console.log('programId', program.programId.toString());
  console.log('vaultPda', vaultPDA.toString(), 'bump', bumpVault);
  const tx = await program.rpc.initialize(
    bumpVault, {
      accounts: {
        vault: vaultPDA,
        admin: provider.wallet.publicKey,
        systemProgram: SystemProgram.programId
      }
    } 
  );
  console.log('migration tx', tx);
}