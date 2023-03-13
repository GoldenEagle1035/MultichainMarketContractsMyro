import * as anchor from "@project-serum/anchor";
import { Program } from "@project-serum/anchor";
import assert from "assert";
import { AccountLayout, TOKEN_PROGRAM_ID, Token } from "@solana/spl-token";
import { Marketplace } from "../target/types/marketplace";  
const { SystemProgram, Keypair, PublicKey } = anchor.web3;

export const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms))
describe("Marketplace", () => {
  // Configure the client to use the local cluster.
  anchor.setProvider(anchor.Provider.env());

  const provider = anchor.getProvider();
  const program = anchor.workspace.Marketplace as Program<Marketplace>;
  const wallet = provider.wallet;
  

  let tx;
  it("create listing-bid", async () => {
    let [vaultPda, bump_vault] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('rewards vault')],
      program.programId
    );

    const nftMint = new PublicKey('G9N3n4wykPDig5pZS3dowrRHDbs5TcXaSKPbjozaZ4qS');
    const nftFrom = new PublicKey('FSyjS3Vbwrg4yTZe23hmBeqTymkL2Hkg8G8rLnXtqTf7');
    let [listingPda, bump_listing] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('listing'), nftMint.toBuffer()],
      program.programId
    );
  
    console.log('listignPda', listingPda.toString());
    const listingPdaInfo = await provider.connection.getAccountInfo(listingPda);
    if (listingPdaInfo) {
      return;
    }

    tx = await program.rpc.createListingAccount(bump_listing, {
      accounts: {
        listingAccount: listingPda,
        owner: wallet.publicKey,
        mint: nftMint,
        systemProgram: SystemProgram.programId
      }
    });
    console.log('finish-create listing account', tx);
    const nftTo = new Keypair();
    const aTokenAccountRent = await provider.connection.getMinimumBalanceForRentExemption(
      AccountLayout.span
    )
    tx = await program.rpc.createListing(1, 1, 200000000, {
      accounts: {
        listingAccount: listingPda,
        vault: vaultPda,
        owner: wallet.publicKey,
        mint: nftMint,
        nftFrom: nftFrom,
        nftTo: nftTo.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID
      },
      signers: [nftTo],
      preInstructions: [
        SystemProgram.createAccount({
          fromPubkey: wallet.publicKey,
          newAccountPubkey: nftTo.publicKey,
          lamports: aTokenAccountRent,
          space: AccountLayout.span,
          programId: TOKEN_PROGRAM_ID
        }),
        Token.createInitAccountInstruction(
          TOKEN_PROGRAM_ID,
          nftMint,
          nftTo.publicKey,
          vaultPda,
        )
      ]
    });
    console.log('finish-create listing', tx);
  });

  it('update listing', async () => {
    const nftMint = new PublicKey('G9N3n4wykPDig5pZS3dowrRHDbs5TcXaSKPbjozaZ4qS');
    let [listingPda, bump_listing] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('listing'), nftMint.toBuffer()],
      program.programId
    );

    tx = await program.rpc.updateListing(1, 500000000, {
      accounts: {
        listingAccount: listingPda,
        owner: wallet.publicKey,
        mint: nftMint
      }
    })
  });

  it('create bids', async () => {
    let [vaultPda, bump_vault] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('rewards vault')],
      program.programId
    );
    const nftMint = new PublicKey('G9N3n4wykPDig5pZS3dowrRHDbs5TcXaSKPbjozaZ4qS');
    let [listingPda, bump_listing] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('listing'), nftMint.toBuffer()],
      program.programId
    );

    const listingData = await program.account.listingAccount.fetch(listingPda);
    assert.equal(listingData.state, 1);
    if (listingData.realBidCount >= 5) return;
    for (let i = 0; i < 5; i ++) {
      const user = new Keypair();
      let [bidPda, bump_bid] = await anchor.web3.PublicKey.findProgramAddress(
        [Buffer.from(`bid${listingData.historialBidCount}`), nftMint.toBuffer()],
        program.programId
      );
      
      console.log(`user${i+1}`, user.publicKey.toString());
      await provider.connection.requestAirdrop(user.publicKey, 2000000000);
      await delay(10000);
      tx = await program.rpc.createBid(1, 600000000, bump_bid, {
        accounts: {
          bidAccount: bidPda,
          mint: nftMint,
          vault: vaultPda,
          user: user.publicKey,
          listingAccount: listingPda,
          systemProgram: SystemProgram.programId
        },
        signers: [user]
      })
      console.log(`finish create user${i+1} bid`);
    }
  });

  it('accept bid', async () => {
    let [vaultPda, bump_vault] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('rewards vault')],
      program.programId
    );
    const nftMint = new PublicKey('G9N3n4wykPDig5pZS3dowrRHDbs5TcXaSKPbjozaZ4qS');
    let [listingPda, bump_listing] = await anchor.web3.PublicKey.findProgramAddress(
      [Buffer.from('listing'), nftMint.toBuffer()],
      program.programId
    );

    const listingData = await program.account.listingAccount.fetch(listingPda);
    let bidUsers = [];
    for (let i = 0; i < listingData.historialBidCount; i ++) {
      let [bidPda, bump_bid] = await anchor.web3.PublicKey.findProgramAddress(
        [Buffer.from(`bid${i}`), nftMint.toBuffer()],
        program.programId
      );

      const bidData = await program.account.bidAccount.fetch(bidPda);
      console.log(`user${i+1}:`, bidData.user.toString(), 'bidprice:', bidData.bidPrice.toNumber());
      bidUsers.push({ ...bidData, bidPda });
    }

    assert(bidUsers.length >= 5);
    const acceptIndex = Math.floor(Math.random() * 6);
    const acceptedUser = bidUsers[acceptIndex];
    console.log('accepted user:', acceptedUser.user.toString(), 'bidprice:', acceptedUser.bidPrice.toNumber());
    const vaultTokenAccounts = await provider.connection.getTokenAccountsByOwner(vaultPda, { mint: nftMint });
    assert(vaultTokenAccounts.value.length > 0);
    const userTokenAccounts = await provider.connection.getTokenAccountsByOwner(acceptedUser.user, { mint: nftMint });
    let nftTo, instructions = [], signers = [];
    const aTokenAccountRent = await provider.connection.getMinimumBalanceForRentExemption(
      AccountLayout.span
    )

    console.log('mint', listingData.mint.toString());
    if (userTokenAccounts.value.length === 0) {
      const nftToKeypair = new Keypair();
      nftTo = nftToKeypair.publicKey;
      instructions.push(
        SystemProgram.createAccount({
          fromPubkey: wallet.publicKey,
          newAccountPubkey: nftTo,
          lamports: aTokenAccountRent,
          space: AccountLayout.span,
          programId: TOKEN_PROGRAM_ID
        }),
        Token.createInitAccountInstruction(
          TOKEN_PROGRAM_ID,
          nftMint,
          nftTo,
          acceptedUser.user,  
      ));
      signers.push(nftToKeypair);
    }
    else {
      nftTo = userTokenAccounts.value[0].pubkey;
    }
    tx = await program.rpc.acceptBid(bump_vault, {
      accounts: {
        acceptBidAccount: acceptedUser.bidPda,
        mint: nftMint,
        vault: vaultPda,
        owner: wallet.publicKey,
        user: acceptedUser.user,
        listingAccount: listingPda,
        nftFrom: vaultTokenAccounts.value[0].pubkey,
        nftTo: nftTo,
        tokenProgram: TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId
      },
      signers,
      preInstructions: instructions
    });
    console.log('finish accept bid', tx);
  })

});
