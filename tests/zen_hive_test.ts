import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that only owner can create challenges",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('zen-hive', 'create-challenge', [
                types.ascii("30 Days of Meditation"),
                types.ascii("Daily meditation practice for 30 days"),
                types.uint(1000),
                types.uint(2000),
                types.uint(100)
            ], deployer.address),
            
            Tx.contractCall('zen-hive', 'create-challenge', [
                types.ascii("30 Days of Meditation"),
                types.ascii("Daily meditation practice for 30 days"),
                types.uint(1000),
                types.uint(2000),
                types.uint(100)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
    }
});

Clarinet.test({
    name: "Users can join and complete challenges",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create challenge
        let block = chain.mineBlock([
            Tx.contractCall('zen-hive', 'create-challenge', [
                types.ascii("30 Days of Meditation"),
                types.ascii("Daily meditation practice for 30 days"),
                types.uint(1000),
                types.uint(2000),
                types.uint(100)
            ], deployer.address)
        ]);
        
        // Join challenge
        let joinBlock = chain.mineBlock([
            Tx.contractCall('zen-hive', 'join-challenge', [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        // Complete challenge
        let completeBlock = chain.mineBlock([
            Tx.contractCall('zen-hive', 'complete-challenge', [
                types.uint(0),
                types.ascii("Great experience meditating for 30 days")
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        joinBlock.receipts[0].result.expectOk();
        completeBlock.receipts[0].result.expectOk();
        
        // Verify challenge info
        let challengeInfo = chain.callReadOnlyFn(
            'zen-hive',
            'get-challenge',
            [types.uint(0)],
            deployer.address
        );
        
        challengeInfo.result.expectOk();
    }
});