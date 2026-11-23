#!/usr/bin/env python3
"""Reference Merkle tree builder for KongMerkleDistributor.

Builds the combined-benefit tree EXACTLY as the contract expects:

    leaf = keccak256(abi.encodePacked(index, account,
                                      airdropAmount, bonusAmount, streakAmount))
    parent = keccak256(min(a, b) ++ max(a, b))   # sorted-pair hashing,
                                                 # as in OpenZeppelin MerkleProof

Use keccak256 (Crypto.Hash.keccak), NOT hashlib.sha3_256 (FIPS SHA3) —
the two differ and a wrong hash makes every proof fail.

Usage as a library:
    from build_tree import build_tree
    root, proofs = build_tree(leaves)   # leaves: list of
                                        # (index, account, airdrop, bonus, streak)
                                        # amounts in WEI (uint256)

Usage as a script (testnet 4-leaf demo tree):
    python3 build_tree.py
"""
import json
import sys

from Crypto.Hash import keccak


def keccak256(data: bytes) -> bytes:
    k = keccak.new(digest_bits=256)
    k.update(data)
    return k.digest()


def leaf_hash(index: int, account: str, airdrop: int, bonus: int, streak: int) -> bytes:
    """abi.encodePacked(index:uint256, account:address,
    airdrop:uint256, bonus:uint256, streak:uint256), keccak256'd."""
    addr = bytes.fromhex(account[2:] if account.startswith("0x") else account)
    assert len(addr) == 20, f"bad address {account}"
    packed = (
        index.to_bytes(32, "big")
        + addr
        + airdrop.to_bytes(32, "big")
        + bonus.to_bytes(32, "big")
        + streak.to_bytes(32, "big")
    )
    return keccak256(packed)


def pair_hash(a: bytes, b: bytes) -> bytes:
    """Sorted-pair hash, matching OpenZeppelin MerkleProof._hashPair."""
    return keccak256(a + b) if a < b else keccak256(b + a)


def build_tree(leaves):
    """leaves: list of (index, account, airdrop, bonus, streak).
    Returns (root_hex, proofs) where proofs[index] is a list of hex
    proof nodes. Leaves are used in the order given; the index in each
    leaf MUST match its position (index 0..n-1) — the contract checks
    the index inside the leaf, so a shuffled tree breaks every proof.
    """
    assert leaves, "empty tree"
    for i, leaf in enumerate(leaves):
        assert leaf[0] == i, f"leaf at position {i} has index {leaf[0]}"

    level = [leaf_hash(*leaf) for leaf in leaves]
    proofs = {i: [] for i in range(len(leaves))}
    # Track which original indices each node covers, so proofs land
    # on the right leaves when a level has an odd count.
    owners = [[i] for i in range(len(leaves))]

    while len(level) > 1:
        nxt, nxt_owners = [], []
        for j in range(0, len(level) - 1, 2):
            for i in owners[j]:
                proofs[i].append("0x" + level[j + 1].hex())
            for i in owners[j + 1]:
                proofs[i].append("0x" + level[j].hex())
            nxt.append(pair_hash(level[j], level[j + 1]))
            nxt_owners.append(owners[j] + owners[j + 1])
        if len(level) % 2 == 1:
            # Odd node promoted unchanged (no self-pairing).
            nxt.append(level[-1])
            nxt_owners.append(owners[-1])
        level, owners = nxt, nxt_owners

    return "0x" + level[0].hex(), proofs


def total_amounts(leaves):
    """Total KONG across all three pools — the pre-root checklist
    requires this to be <= 33,000,000 ether."""
    return sum(a + b + s for (_, _, a, b, s) in leaves)


if __name__ == "__main__":
    ETHER = 10**18
    # 4-leaf demo tree used for the testnet live test (23 Nov 2026).
    # Leaf 0 is the testnet deployer, so the claim is verifiable on-chain.
    def _addr(suffix):
        return "0x" + "0" * (40 - len(suffix)) + suffix

    demo = [
        (0, "0x5951eBe74f43CbA573064a23dE2EAcA18F6a1601", 10_000 * ETHER, 120_000 * ETHER, 3_000 * ETHER),
        (1, _addr("a11ce"), 20_000 * ETHER, 0, 1_500 * ETHER),
        (2, _addr("ca901"), 5_000 * ETHER, 80_000 * ETHER, 0),
        (3, _addr("da9e"), 0, 40_000 * ETHER, 2_500 * ETHER),
    ]
    root, proofs = build_tree(demo)
    print(json.dumps({
        "root": root,
        "total_wei": str(total_amounts(demo)),
        "total_kong": total_amounts(demo) / ETHER,
        "proofs": {str(k): v for k, v in proofs.items()},
    }, indent=2))
