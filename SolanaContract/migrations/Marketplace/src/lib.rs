use anchor_lang::prelude::*;
use anchor_lang::solana_program::{
    program::{invoke_signed, invoke},
    system_instruction,
};
use anchor_spl::token::{self, TokenAccount, Token, Mint};
use crate::constants::*;
declare_id!("9mQisfKUTdSWFdonYYbnA3Lnzks1bR3b3tHerHZAgByt");

mod constants {
    pub const LAMPORTS_PER_SOL: u64 = 1000000000;
    pub const LISTING_STATE_ZERO: u8 = 0;
    pub const LISTING_STATE_BID: u8 = 1;
    pub const LISTING_STATE_OFFER: u8 = 2;

    pub const BID_STATE_ZERO: u8 = 0;
    pub const BID_STATE_PENDING: u8 = 1;
    pub const BID_STATE_ACCEPT: u8 = 2;
}

#[program]
pub mod marketplace {
    use super::*;
    pub fn initialize(ctx: Context<InitializeContext>, bump: u8) -> Result<()> {
        Ok(())
    }

    pub fn create_listing_account(ctx: Context<CreateListingAccountContext>, bump: u8) -> Result<()> {
        let listing_account = &mut ctx.accounts.listing_account;
        let owner = &ctx.accounts.owner;
        let mint = &ctx.accounts.mint;

        listing_account.owner = owner.to_account_info().key();
        listing_account.mint = mint.to_account_info().key();
        listing_account.real_bid_count = 0;
        listing_account.historial_bid_count = 0;
        listing_account.state = LISTING_STATE_ZERO;
        listing_account.bump_listing = bump;
        Ok(())
    }

    pub fn create_listing(ctx: Context<CreateListingContext>, state: u8, price_high: u32, price_low: u32) -> Result<()> {
        let listing_account = &mut ctx.accounts.listing_account;
        let owner = &ctx.accounts.owner;
        let mint = &ctx.accounts.mint;

        if listing_account.owner != owner.to_account_info().key() {
            return Err(error!(CustomError::InvalidOwner));
        }

        if listing_account.mint != mint.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }

        if state != LISTING_STATE_BID && state != LISTING_STATE_OFFER {
            return Err(error!(CustomError::InvalidState));
        }

        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            token::Transfer {
                from: ctx.accounts.nft_from.to_account_info(),
                to: ctx.accounts.nft_to.to_account_info(),
                authority: ctx.accounts.owner.to_account_info()
            }
        );

        token::transfer(cpi_ctx, 1)?;
        listing_account.price = price_high as u64 * LAMPORTS_PER_SOL + price_low as u64;
        listing_account.state = state; // either 1 or 2, 1-bid 2-offer
        Ok(())
    }

    pub fn update_listing(ctx: Context<UpdateListingContext>, price_high: u32, price_low: u32) -> Result<()> {
        let listing_account = &mut ctx.accounts.listing_account;
        let owner = &ctx.accounts.owner;
        let mint = &ctx.accounts.mint;

        if listing_account.owner != owner.to_account_info().key() {
            return Err(error!(CustomError::InvalidOwner));
        }

        if listing_account.mint != mint.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }
        
        if listing_account.state != LISTING_STATE_BID && listing_account.state != LISTING_STATE_OFFER {
            return Err(error!(CustomError::InvalidState));
        }

        listing_account.price = price_high as u64 * LAMPORTS_PER_SOL + price_low as u64;

        Ok(())

    }

    pub fn cancel_listing(ctx: Context<CancelListingContext>, bump_vault: u8) -> Result<()> {
        let listing_account = &mut ctx.accounts.listing_account;
        let vault = &mut ctx.accounts.vault;

        let vault_seeds = &[
            b"rewards vault".as_ref(),
            &[bump_vault],
        ];

        let vault_signer = &[&vault_seeds[..]];
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            token::Transfer {
                from: ctx.accounts.nft_from.to_account_info(),
                to: ctx.accounts.nft_to.to_account_info(),
                authority: vault.to_account_info()
            },
            vault_signer
        );

        token::transfer(cpi_ctx, 1)?;

        listing_account.state = LISTING_STATE_ZERO;
        listing_account.real_bid_count = 0;
        Ok(())
    }

    pub fn create_bid(ctx: Context<CreateBidContext>, bid_price_high: u32, bid_price_low: u32, bump: u8) -> Result<()> {
        let bid_account = &mut ctx.accounts.bid_account;
        let listing_account = &mut ctx.accounts.listing_account;
        let vault = &ctx.accounts.vault;
        let user = &ctx.accounts.user;
        let mint = &ctx.accounts.mint;

        if listing_account.mint != mint.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }

        if listing_account.state != LISTING_STATE_BID && listing_account.state != LISTING_STATE_OFFER {
            return Err(error!(CustomError::InvalidState));
        }

        let bid_price: u64 = bid_price_high as u64 * LAMPORTS_PER_SOL + bid_price_low as u64;
        if listing_account.price > bid_price {
            return Err(error!(CustomError::UnAcceptablePrice));
        }

        bid_account.user = user.to_account_info().key();
        bid_account.mint = mint.to_account_info().key();
        bid_account.bid_price = bid_price;
        bid_account.state = BID_STATE_PENDING;
        bid_account.bump_bid = bump;

        listing_account.real_bid_count += 1;
        listing_account.historial_bid_count += 1;

        if listing_account.state == LISTING_STATE_BID {
            invoke(
                &system_instruction::transfer(
                    &user.to_account_info().key(),
                    &vault.to_account_info().key(),
                    bid_account.bid_price
                ),
                &[
                    user.to_account_info(),
                    vault.to_account_info(),
                ]        
            )?;
        }

        Ok(())

    }

    pub fn accept_bid(ctx: Context<AcceptBidContext>, bump_vault: u8) -> Result<()> {
        let accept_bid_account = &mut ctx.accounts.accept_bid_account;
        let listing_account = &mut ctx.accounts.listing_account;
        let owner = &ctx.accounts.owner;
        let user = &ctx.accounts.user;
        let mint = &ctx.accounts.mint;
        let vault = &ctx.accounts.vault;

        if listing_account.owner != owner.to_account_info().key() {
            return Err(error!(CustomError::InvalidOwner));
        }

        if listing_account.mint != mint.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }
        
        if listing_account.state != LISTING_STATE_BID && listing_account.state != LISTING_STATE_OFFER {
            return Err(error!(CustomError::InvalidState));
        }

        if accept_bid_account.user != user.to_account_info().key() {
            return Err(error!(CustomError::InvalidUser));
        }

        if accept_bid_account.mint != mint.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }


        if listing_account.state == LISTING_STATE_BID {

            let vault_seeds = &[b"rewards vault".as_ref(), &[bump_vault]];
            let vault_signer = &[&vault_seeds[..]]; 
            invoke_signed(
                &system_instruction::transfer(
                    &vault.to_account_info().key(),
                    &owner.to_account_info().key(),
                    accept_bid_account.bid_price
                ),
                &[
                    vault.to_account_info(),
                    owner.to_account_info(),
                ],
                vault_signer
    
            )?;
    
            let cpi_ctx = CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                token::Transfer {
                    from: ctx.accounts.nft_from.to_account_info(),
                    to: ctx.accounts.nft_to.to_account_info(),
                    authority: vault.to_account_info()
                },
                vault_signer
            );
    
            token::transfer(cpi_ctx, 1)?;
        }

        accept_bid_account.state = BID_STATE_ACCEPT;
        listing_account.state = 0;
        Ok(())
    }

    pub fn cancel_bid(ctx: Context<CancelBidContext>, bump_vault: u8) -> Result<()> {
        let cancel_bid_account = &mut ctx.accounts.cancel_bid_account;
        let listing_account = &mut ctx.accounts.listing_account;
        let user = &ctx.accounts.user;
        let mint = &ctx.accounts.mint;
        let vault = &ctx.accounts.vault;

        if listing_account.mint != mint.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }

        if cancel_bid_account.user != user.to_account_info().key() {
            return Err(error!(CustomError::InvalidUser));
        }

        if cancel_bid_account.mint != user.to_account_info().key() {
            return Err(error!(CustomError::InvalidNft));
        }

        let vault_seeds = &[b"rewards vault".as_ref(), &[bump_vault]];
        let vault_signer = &[&vault_seeds[..]]; 
        if listing_account.state == LISTING_STATE_BID {
            invoke_signed(
                &system_instruction::transfer(
                    &vault.to_account_info().key(),
                    &user.to_account_info().key(),
                    cancel_bid_account.bid_price
                ),
                &[
                    vault.to_account_info(),
                    user.to_account_info(),
                ],
                vault_signer
            )?;
        }
        listing_account.real_bid_count -= 1;
        cancel_bid_account.state = BID_STATE_ZERO;
        Ok(())
    }

}


#[derive(Accounts)]
#[instruction(bump: u8)]
pub struct InitializeContext<'info> {
    #[account(init, seeds = [b"rewards vault".as_ref()], bump, space = 8 + 1, payer = admin)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub vault: AccountInfo<'info>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>
}

#[derive(Accounts)]
#[instruction(bump: u8)]
pub struct CreateListingAccountContext<'info> {
    #[account(init, seeds = [b"listing".as_ref(), mint.key().as_ref()], bump, payer = owner, space = 8 + 32 + 32 + 8 + 4 + 4 + 1 + 1)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub listing_account: Account<'info, ListingAccount>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub mint: Account<'info, Mint>,
    pub system_program: Program<'info, System>
}

#[derive(Accounts)]
pub struct CreateListingContext<'info> {
    #[account(mut)]
    pub listing_account: Account<'info, ListingAccount>,
    #[account(mut)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub vault: AccountInfo<'info>,
    pub owner: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = nft_from.mint == mint.key() && nft_from.owner == owner.key() && nft_from.amount == 1)]
    pub nft_from: Account<'info, TokenAccount>,
    #[account(mut, constraint = nft_to.mint == mint.key() && nft_to.owner == vault.key())]
    pub nft_to: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>
}

#[derive(Accounts)]
pub struct UpdateListingContext<'info> {
    #[account(mut)]
    pub listing_account: Account<'info, ListingAccount>,
    pub owner: Signer<'info>,
    pub mint: Account<'info, Mint>
}

#[derive(Accounts)]
pub struct CancelListingContext<'info> {
    #[account(mut)]
    pub listing_account: Account<'info, ListingAccount>,
    #[account(mut)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub vault: AccountInfo<'info>,
    pub owner: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = nft_from.mint == mint.key() && nft_from.owner == vault.key() && nft_from.amount == 1)]
    pub nft_from: Account<'info, TokenAccount>,
    #[account(mut, constraint = nft_to.mint == mint.key() && nft_to.owner == owner.key())]
    pub nft_to: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>
}

#[derive(Accounts)]
#[instruction(bump: u8)]
pub struct CreateBidContext<'info> {
    #[account(init, seeds = [format!("bid{}", listing_account.historial_bid_count).as_ref(), mint.key().as_ref()], bump, payer = user, space = 8 + 32 + 32 + 4 + 8 + 1 + 1)]
    pub bid_account: Account<'info, BidAccount>,
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub vault: AccountInfo<'info>,
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(mut)]
    pub listing_account: Account<'info, ListingAccount>,
    pub system_program: Program<'info, System>
}

#[derive(Accounts)]
pub struct AcceptBidContext<'info> {
    #[account(mut)]
    pub accept_bid_account: Account<'info, BidAccount>,
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub vault: AccountInfo<'info>,
    #[account(mut)]
    pub owner: Signer<'info>,
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub user: AccountInfo<'info>,
    #[account(mut)]
    pub listing_account: Account<'info, ListingAccount>,
    #[account(mut, constraint = nft_from.mint == mint.key() && nft_from.owner == vault.key() && nft_from.amount == 1)]
    pub nft_from: Account<'info, TokenAccount>,
    #[account(mut, constraint = nft_to.mint == mint.key() && nft_to.owner == user.key())]
    pub nft_to: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>
}


#[derive(Accounts)]
pub struct CancelBidContext<'info> {
    #[account(mut)]
    pub cancel_bid_account: Account<'info, BidAccount>,
    pub mint: Account<'info, Mint>,
    pub user: Signer<'info>,
    #[account(mut)]
    /// CHECK: This is not dangerous because we don't read or write from this account
    pub vault: AccountInfo<'info>,
    #[account(mut)]
    pub listing_account: Account<'info, ListingAccount>
}

#[account]
pub struct ListingAccount {
    pub owner: Pubkey,
    pub mint: Pubkey,
    pub price: u64,
    pub real_bid_count: u32,
    pub historial_bid_count: u32,
    pub state: u8, // 2-offer listing, 1-bid listing, 0-unlisting
    pub bump_listing: u8
}

#[account]
pub struct BidAccount {
    pub user: Pubkey,
    pub mint: Pubkey,
    pub index: u32,
    pub bid_price: u64,
    pub state: u8, // 1-Accept, 0-pending
    pub bump_bid: u8
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid Owner")]
    InvalidOwner,
    #[msg("Invalid Nft")]
    InvalidNft,
    #[msg("Invalid State")]
    InvalidState,
    #[msg("Invalid User")]
    InvalidUser,
    #[msg("UnAcceptable Price")]
    UnAcceptablePrice
}