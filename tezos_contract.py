import smartpy as sp

# Import FA2 template
FA2 = sp.io.import_script_from_url("https://smartpy.io/dev/templates/FA2.py")

class Token(FA2.FA2):
    pass


class Marketplace(sp.Contract):
    def __init__(self, token, metadata, admin):
        self.royalties = 0
        self.fee =0
        self.init(
            price_for_minting = sp.mutez(1000),
            to_cadaf = sp.nat(3),
            token = token,
            metadata = metadata,
            admin = admin,
            data = sp.big_map(tkey=sp.TNat, tvalue=sp.TRecord(holder=sp.TAddress, author = sp.TAddress, owner = sp.TAddress, royalties=sp.TNat, token_id=sp.TNat, link_to_json = sp.TBytes, collectable=sp.TBool, amount=sp.TMutez )),
            token_id = 0,
            )

    @sp.entry_point
    def mint(self, params):
        sp.verify(sp.amount == self.data.price_for_minting)
        sp.verify(params.royalties>=1)
        sp.verify(params.royalties<=7)
        
        c = sp.contract(
            sp.TRecord(
            address=sp.TAddress,
            amount=sp.TNat,
            token_id=sp.TNat,
            metadata=sp.TMap(sp.TString, sp.TBytes)
            ), 
            self.data.token, 
            entry_point = "mint").open_some()
            
        sp.transfer(
            sp.record(
            address = sp.self_address,
            amount = 1,
            token_id = self.data.token_id,
            metadata={ '' : params.metadata }
            ), 
            sp.mutez(0), 
            c)
        
        self.data.data[self.data.token_id] = sp.record(holder=sp.self_address, author = sp.sender, owner = sp.sender, royalties = params.royalties, token_id=self.data.token_id, link_to_json = params.metadata, collectable=False, amount = sp.mutez(1))
        self.fa2_transfer(self.data.token, sp.self_address, sp.sender, self.data.token_id, 1)
        self.data.token_id += 1


    @sp.entry_point
    def set_cadaf_percentage(self, params):
        sp.verify(sp.sender == self.data.admin)
        sp.verify(params<50)
        self.data.to_cadaf = params
    
    @sp.entry_point
    def set_price_for_minting(self, params):
        sp.verify(sp.sender == self.data.admin)
        self.data.price_for_minting = params
    
    @sp.entry_point
    def transfer_token(self, params):
        sp.verify(self.data.data[params.token_id].owner == sp.sender)

        self.fa2_transfer(self.data.token, self.data.data[params.token_id].owner, params.new_owner, params.token_id, 1)

        self.data.data[params.token_id].owner = params.new_owner
        self.data.data[params.token_id].collectable = False
        


    @sp.entry_point
    def cancel_selling(self, params):
        sp.verify(self.data.data[params.token_id].collectable == True) 
        sp.verify(self.data.data[params.token_id].owner == sp.sender)
        self.data.data[params.token_id].collectable = False
        self.data.data[params.token_id].amount = sp.mutez(0)

    @sp.entry_point
    def collect_management_rewards(self, params):
        sp.verify(sp.sender == self.data.admin)
        sp.send(params.address, params.amount)

    @sp.entry_point
    def collect(self, params):
        sp.verify(sp.amount == self.data.data[params.token_id].amount)
        sp.verify(self.data.data[params.token_id].amount != sp.mutez(0))
        sp.verify(self.data.data[params.token_id].collectable == True) 
        sp.verify(self.data.data[params.token_id].owner != sp.sender)

        #sending rewards
        toCreator = self.data.data[params.token_id].royalties
        toSender = sp.as_nat(100-toCreator)-self.data.to_cadaf
        sp.send(self.data.data[params.token_id].author, sp.split_tokens(sp.amount, toCreator, 100))
        sp.send(self.data.data[params.token_id].owner, sp.split_tokens(sp.amount,  sp.as_nat(toSender), 100))

        self.fa2_transfer(self.data.token, self.data.data[params.token_id].owner, sp.sender, params.token_id, 1)

        self.data.data[params.token_id].collectable = False
        self.data.data[params.token_id].amount = sp.mutez(0)
        self.data.data[params.token_id].owner = sp.sender
        
        
        


    @sp.entry_point
    def sell_token(self, params):
        sp.verify((self.data.data[params.token_id].owner == sp.sender) & (params.amount > sp.mutez(0)))
        self.data.data[params.token_id].collectable = True
        self.data.data[params.token_id].amount = params.amount

    @sp.entry_point
    def update_admin(self, params):
        sp.verify(sp.sender == self.data.admin)
        self.data.admin = params
        
    def fa2_transfer(self, fa2, from_, to_, token_id, amount):
        c = sp.contract(sp.TList(sp.TRecord(from_=sp.TAddress, txs=sp.TList(sp.TRecord(amount=sp.TNat, to_=sp.TAddress, token_id=sp.TNat).layout(("to_", ("token_id", "amount")))))), fa2, entry_point='transfer').open_some()
        sp.transfer(sp.list([sp.record(from_=from_, txs=sp.list([sp.record(amount=amount, to_=to_, token_id=token_id)]))]), sp.mutez(0), c)



@sp.add_test(name = "Non Fungible Token")
def test():
    scenario = sp.test_scenario()
    
    admin = sp.test_account("admin")
    mark = sp.test_account("user1")
    elon = sp.test_account("user2")
    vera = sp.test_account("user3")
    
    scenario.h1("Token contract")
    token_contract = Token(FA2.FA2_config(non_fungible = True), admin = admin.address, metadata = sp.utils.metadata_of_url("ipfs://QmeF48X9tNUriCibMUwBbkAASAEzS53zkg8CxEk1qHmjpy"))
    
    scenario += token_contract

    scenario.h1("MarketPlace contract")
    marketplace = Marketplace(token_contract.address, sp.utils.metadata_of_url("ipfs://QmR3NfLjUY4nxqhrcuFqsxEXXVJr22A6QvSskjd9MBzT9A"), admin.address)
    scenario += marketplace
    
    scenario.h2("Successfully set administrator for token contract when sender is admin")
    scenario += token_contract.set_administrator(marketplace.address).run(sender = admin)
    
    scenario.h2("Successfully set price for minting when user is admin")
    scenario += marketplace.set_price_for_minting(sp.mutez(100)).run(sender = admin)
    
    scenario.h2("Sucessfully mint token when minting price set")
    scenario += marketplace.mint(sp.record(royalties = 3, metadata = sp.pack("123423"))).run(sender = vera, amount = sp.mutez(100))
    
    scenario.h2("Successfully set of token as available to purchase")
    scenario += marketplace.sell_token(sp.record(token_id = 0, amount = sp.mutez(560))).run(sender = vera)
    
    scenario.h2 ("Successfully purchase of token when token available for purchase")
    scenario += marketplace.collect(sp.record(token_id = 0)).run(sender = mark, amount = sp.mutez(560))
    
    scenario.h2("Successfully set of token as available for purchase when token was once purchased")
    scenario += marketplace.sell_token(sp.record(token_id = 0, amount = sp.mutez(900))).run(sender = mark)
    
    scenario.h2 ("Successfully purchase of token when token available for purchase and token was once purchased")
    scenario += marketplace.collect(sp.record(token_id = 0)).run(sender = vera, amount = sp.mutez(900))
    
    scenario.h2 ("Successfully transfer of token that was once purchased")
    scenario += marketplace.transfer_token(sp.record(token_id = 0, new_owner=mark.address)).run(sender = vera)
    
    scenario.h2("Successfully set of token as available to purchase when token was once transferred")
    scenario += marketplace.sell_token(sp.record(token_id = 0, amount = sp.mutez(900))).run(sender = mark)
    
    scenario.h2 ("Successfully purchase of token when token available for purchase and was once transferred")
    scenario += marketplace.collect(sp.record(token_id = 0)).run(sender = vera, amount = sp.mutez(900))
    
    scenario.h2 ("Successfully transfer of token that was once transferred")
    scenario += marketplace.transfer_token(sp.record(token_id = 0, new_owner=elon.address)).run(sender = vera)