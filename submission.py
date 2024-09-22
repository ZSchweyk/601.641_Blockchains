import hashlib
from typing import List, Tuple, Optional
from nacl.signing import SigningKey, VerifyKey
from nacl.encoding import HexEncoder
from copy import deepcopy

DIFFICULTY = 0x07FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

"""
Please do not modify any of the signatures on the classes below so the
autograder can properly run your submission. You are free (and encouraged!) to
add additional data members as you implement these functions.
"""

class Output:
    """
    A transaction output.
    """

    def __init__(self, value: int, pub_key: str):
        self.value = value
        self.pub_key = pub_key

    # Serialize the output to bytes
    def to_bytes(self) -> bytes:
        return self.value.to_bytes(4, 'big', signed=False) + bytes.fromhex(self.pub_key)

class Input:
    """
    A transaction input. The number refers to the transaction number where the
    input was generated (see `Transaction.update_number()`).
    """

    def __init__(self, output: Output, number: str):
        self.output = output
        self.number = number

    # Serialize the output to bytes
    def to_bytes(self) -> bytes:
        return self.output.to_bytes() + bytes.fromhex(self.number)


class Transaction:
    """
    A transaction in a block. A signature is the hex-encoded string that
    represents the bytes of the signature.
    """

    def __init__(self, inputs: List[Input], outputs: List[Output], sig_hex: Optional[str]):
        self.inputs = inputs
        self.outputs = outputs
        self.sig_hex = sig_hex

        self.update_number()

    def get_inputs(self) -> List[Input]:
        return self.inputs
    
    def get_outputs(self) -> List[Output]:
        return self.outputs

    # Set the transaction number to be SHA256 of self.to_bytes().
    def update_number(self):
        self.number = hashlib.sha256(self.to_bytes()).digest()

    # Get the bytes of the transaction before signatures; signers need to sign
    # this value!
    def bytes_to_sign(self) -> str:
        m = b''

        for i in self.inputs:
            m += i.to_bytes()
        
        for o in self.outputs:
            m += o.to_bytes()

        return m.hex()
    
    def to_bytes(self) -> str:
        m = b''

        for i in self.inputs:
            m += i.to_bytes()
        
        for o in self.outputs:
            m += o.to_bytes()

        m += bytes.fromhex(self.sig_hex)

        return m.hex()
    
class Block:
    """
    A block on a blockchain. Prev is a string that contains the hex-encoded hash
    of the previous block.
    """

    def __init__(self, prev: str, tx: Transaction, nonce: Optional[str]):
        self.tx = tx
        self.nonce = nonce
        self.prev = prev

    # Find a valid nonce such that the hash below is less than the DIFFICULTY
    # constant. Record the nonce as a hex-encoded string (bytearray.hex(), see
    # Transaction.to_bytes() for an example).
    def mine(self):
        self.nonce = "0"  # hex-encoded string starting at 0
        while True:
            hash_hex_digest = self.hash()
            if int(hash_hex_digest, 16) < DIFFICULTY:
                self.pow = int.from_bytes(bytes.fromhex(hash_hex_digest), "big")
                break

            self.nonce = f"{chr(int(self.nonce, 16) + 1)}"

        
        return self.nonce
    
    # Hash the block.
    def hash(self) -> str:
        m = hashlib.sha256()

        m.update(bytes.fromhex(self.prev))
        m.update(bytes.fromhex(self.tx.to_bytes()))
        m.update(bytes.fromhex(self.nonce))

        return m.hexdigest()
    
class Blockchain:
    """
    A blockchain. This class is provided for convenience only; the autograder
    will not call this class.
    """
    
    def __init__(self, chain: List[Block]):
        self.chain = []
        self.utxos = []
        for block in chain:
            self.append(block)
        
    def __len__(self):
        return len(self.chain)
    
    def get_blocks(self) -> List[Block]:
        return self.chain
    
    def create_new_blockchain(self, block: Block):        
        repeated_blocks = deepcopy(self.chain)[:self.chain.index(block)+1]
        return Blockchain(repeated_blocks)
    
    def get_last_block_hash(self) -> str:
        return self.chain[-1].hash()
    
    def append(self, block: Block) -> bool:
        self.chain.append(block)
        for tx_input in block.tx.get_inputs():
            # remove from utxos
            self.utxos.remove(tx_input.output)
            
        for tx_output in block.tx.get_outputs():
            # add to utxos
            self.utxos.append(tx_output)

class Node:
    """
    All chains that the node is currently aware of.
    """
    def __init__(self):
        # We will not access this field, you are free change it if needed.
        self.chains: List[Blockchain] = []

    # Create a new chain with the given genesis block. The autograder will give
    # you the genesis block.
    def new_chain(self, genesis: Block):
        self.chains.append(Blockchain([genesis]))

    # Attempt to append a block broadcast on the network; return true if it is
    # possible to add (e.g. could be a fork). Return false otherwise.
    def append(self, block: Block) -> bool:
        if block.pow != int.from_bytes(bytes.fromhex(block.hash()), "big"):
            return False
        
        for bc in self.chains:
            for b in bc.get_blocks():
                if block.prev == b.hash():
                    if b.hash() == bc.get_last_block_hash():  # b is last block in chain
                        if self.verify_tx(block.tx, bc):
                            bc.append(block)
                            return True
                        return False
                    else:  # b is in middle of chain
                        # fork
                        new_bc: Blockchain =  bc.create_new_blockchain(b)  # create a new Blockchain object from those blocks 
                        if self.verify_tx(block.tx, bc):
                            new_bc.append(block)  # append `block` to that new Blockchain object
                            self.chains.append(new_bc)  # append new blockchain to chains
                            return True
                        return False
        
        return False

    def get_longest_chain(self):
        return max(self.chains, key=lambda blockchain: len(blockchain))


    def verify_tx(self, tx: Transaction, bc: Blockchain):
        return self.check_double_spend(tx, bc) and self.verify_tx_num_and_output_exist(tx.get_inputs(), bc)

    def check_double_spend(self, tx: Transaction, blockchain: Blockchain):
        for input in tx.get_inputs():
            if input.number not in blockchain.utxos:
                return False
        return True

    def verify_tx_num_and_output_exist(self, inputs: List[Input], blockchain: Blockchain):
        for input in inputs:
            found_tx_num_match = False
            for block in blockchain.get_blocks():
                if input.number == block.tx.number: # Check if a tx number on the blockchain matches the number field of input
                    input_is_an_output: bool = bool(sum([
                        input.output.value == trans_output.value and input.output.pub_key == trans_output.pub_key
                        for trans_output in block.tx.get_outputs()
                    ]))
                    if not input_is_an_output:
                        return False
                    found_tx_num_match = True
                    break
            
            if not found_tx_num_match:
                return False
        
        return True


    # Build a block on the longest chain you are currently tracking. If the
    # transaction is invalid (e.g. double spend), return None.
    def build_block(self, tx: Transaction) -> Optional[Block]:
        # Get longest blockchain
        blockchain: Blockchain = self.get_longest_chain()

        if not self.verify_tx(tx, blockchain):
            return None

        # Create a block object
        block = Block(blockchain.get_last_block_hash(), tx, None)

        # mine the block
        block.mine()
        blockchain.append(block)
        return block

# Build and sign a transaction with the given inputs and outputs. If it is
# impossible to build a valid transaction given the inputs and outputs, you
# should return None. Do not verify that the inputs are unspent.
def build_transaction(inputs: List[Input], outputs: List[Output], signing_key: SigningKey) -> Optional[Transaction]:
    
    # Check that the sum of the outputs do not exceed the sum of the inputs...
    input_sum = sum([input.output.value for input in inputs])
    output_sum = sum([output.value for output in outputs])
    if output_sum > input_sum:
        return None

    # Check public keys of inputs match...
    for i in range(len(inputs) - 1):
        if inputs[i].output.pub_key != inputs[i+1].output.pub_key:
            return None
    


    m = b''
    for i in inputs:
        m += i.to_bytes()
    
    for o in outputs:
        m += o.to_bytes()

    signature = signing_key.sign(m.hex())
    tx = Transaction(inputs, outputs, signature.signature.hex())
    return tx
    