import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Original tests...

Clarinet.test({
    name: "Ensure users can stake and unstake tokens",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('zen-hive', 'stake-tokens', [
                types.uint(1000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        
        let unstakeBlock = chain.mineBlock([
            Tx.contractCall('zen-hive', 'unstake-tokens', [
                types.uint(500)
            ], wallet1.address)
        ]);
        
        unstakeBlock.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Test governance proposal creation and voting",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Stake tokens first
        let stakeBlock = chain.mineBlock([
            Tx.contractCall('zen-hive', 'stake-tokens', [
                types.uint(100000)
            ], wallet1.address)
        ]);
        
        // Create proposal
        let proposalBlock = chain.mineBlock([
            Tx.contractCall('zen-hive', 'create-proposal', [
                types.ascii("Test Proposal"),
                types.ascii("This is a test proposal"),
                types.uint(100)
            ], wallet1.address)
        ]);
        
        // Vote on proposal
        let voteBlock = chain.mineBlock([
            Tx.contractCall('zen-hive', 'vote-on-proposal', [
                types.uint(0),
                types.bool(true)
            ], wallet1.address)
        ]);
        
        proposalBlock.receipts[0].result.expectOk();
        voteBlock.receipts[0].result.expectOk();
    }
});
