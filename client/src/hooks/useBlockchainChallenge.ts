import { usePrivy } from '@privy-io/react-auth';
import { useToast } from '@/hooks/use-toast';
import { ethers } from 'ethers';
import { useState } from 'react';

const CHALLENGE_FACTORY_ABI = [
  'function createP2PChallenge(address participant, address paymentToken, uint256 stakeAmount, uint256 pointsReward, string calldata metadataURI) external nonReentrant returns (uint256)',
  'function acceptP2PChallenge(uint256 challengeId) external nonReentrant',
];

interface CreateP2PChallengeParams {
  opponentAddress: string;
  stakeAmount: string; // in wei
  paymentToken: string;
  pointsReward: string;
  metadataURI: string;
}

interface AcceptChallengeParams {
  challengeId: number;
  stakeAmount: string; // in wei
  paymentToken: string;
}

interface TransactionResult {
  transactionHash: string;
  blockNumber: number;
  status: 'success';
}

/**
 * Hook for user-initiated blockchain challenge operations
 * Handles signing and submitting transactions via Privy wallet
 */
export function useBlockchainChallenge() {
  const { user, getEthereumProvider } = usePrivy();
  const { toast } = useToast();
  const [isRetrying, setIsRetrying] = useState(false);

  const FACTORY_ADDRESS = import.meta.env.VITE_CHALLENGE_FACTORY_ADDRESS || '0xEB38Cfd6a9Ad4D07b58A5596cadA567E37870e11';
  const RPC_URL = import.meta.env.VITE_BASE_TESTNET_RPC || 'https://sepolia.base.org';
  const MAX_RETRIES = 3;
  const RETRY_DELAY = 2000; // 2 seconds

  const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

  /**
   * Retry logic for failed transactions
   */
  const retryTransaction = async (
    fn: () => Promise<TransactionResult>,
    operationName: string
  ): Promise<TransactionResult> => {
    let lastError: any;
    
    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        console.log(`🔄 ${operationName} attempt ${attempt}/${MAX_RETRIES}`);
        const result = await fn();
        return result;
      } catch (error: any) {
        lastError = error;
        console.error(`❌ Attempt ${attempt} failed:`, error.message);

        // Don't retry on user cancellation
        if (error.message?.includes('user rejected') || 
            error.message?.includes('User denied') ||
            error.code === 'ACTION_REJECTED') {
          console.log('⚠️ User cancelled transaction, not retrying');
          throw error;
        }

        // On last attempt, throw the error
        if (attempt === MAX_RETRIES) {
          console.error(`❌ All ${MAX_RETRIES} attempts failed`);
          throw error;
        }

        // Wait before retrying
        console.log(`⏳ Waiting ${RETRY_DELAY}ms before retry...`);
        await wait(RETRY_DELAY);
      }
    }

    throw lastError;
  };

  /**
   * Create a P2P challenge and submit to blockchain
   */
  const createP2PChallenge = async (params: CreateP2PChallengeParams): Promise<TransactionResult> => {
    try {
      if (!user) {
        throw new Error('User not authenticated');
      }

      const provider = await getEthereumProvider();
      if (!provider) {
        throw new Error('Ethereum provider not available');
      }

      const signer = await provider.getSigner();
      const userAddress = await signer.getAddress();

      console.log(`🔗 Creating P2P challenge from ${userAddress}...`);

      // Create contract instance with user's signer
      const contract = new ethers.Contract(
        FACTORY_ADDRESS,
        CHALLENGE_FACTORY_ABI,
        signer
      );

      // Convert amounts to BigInt
      const stakeWei = BigInt(params.stakeAmount);
      const pointsWei = BigInt(params.pointsReward);

      console.log(`📝 Transaction details:`);
      console.log(`   Opponent: ${params.opponentAddress}`);
      console.log(`   Stake: ${params.stakeAmount} wei`);
      console.log(`   Token: ${params.paymentToken}`);
      console.log(`   Points: ${params.pointsReward}`);

      setIsRetrying(true);

      return await retryTransaction(async () => {
        console.log(`💳 Awaiting user to sign transaction...`);

        const tx = await contract.createP2PChallenge(
          params.opponentAddress,
          params.paymentToken,
          stakeWei,
          pointsWei,
          params.metadataURI
        );

        console.log(`⏳ Transaction submitted: ${tx.hash}`);
        toast({
          title: 'Transaction Submitted',
          description: `Hash: ${tx.hash?.slice(0, 10)}...`,
        });

        const receipt = await tx.wait();

        if (!receipt) {
          throw new Error('Transaction receipt is null');
        }

        console.log(`✅ P2P challenge created on-chain!`);
        console.log(`   TX: ${receipt.transactionHash}`);
        console.log(`   Block: ${receipt.blockNumber}`);

        return {
          transactionHash: receipt.transactionHash,
          blockNumber: receipt.blockNumber,
          status: 'success' as const,
        };
      }, 'Create P2P Challenge');

    } catch (error: any) {
      console.error('Failed to create P2P challenge on-chain:', error);
      throw error;
    } finally {
      setIsRetrying(false);
    }
  };

  /**
   * Accept a P2P challenge and submit to blockchain
   */
  const acceptP2PChallenge = async (params: AcceptChallengeParams): Promise<TransactionResult> => {
    try {
      if (!user) {
        throw new Error('User not authenticated');
      }

      const provider = await getEthereumProvider();
      if (!provider) {
        throw new Error('Ethereum provider not available');
      }

      const signer = await provider.getSigner();
      const userAddress = await signer.getAddress();

      console.log(`🔗 Accepting P2P challenge ${params.challengeId}...`);

      const contract = new ethers.Contract(
        FACTORY_ADDRESS,
        CHALLENGE_FACTORY_ABI,
        signer
      );

      setIsRetrying(true);

      return await retryTransaction(async () => {
        console.log(`💳 Awaiting user to sign transaction...`);

        const tx = await contract.acceptP2PChallenge(params.challengeId);

        console.log(`⏳ Transaction submitted: ${tx.hash}`);
        toast({
          title: 'Transaction Submitted',
          description: `Hash: ${tx.hash?.slice(0, 10)}...`,
        });

        const receipt = await tx.wait();

        if (!receipt) {
          throw new Error('Transaction receipt is null');
        }

        console.log(`✅ P2P challenge accepted on-chain!`);
        console.log(`   TX: ${receipt.transactionHash}`);

        return {
          transactionHash: receipt.transactionHash,
          blockNumber: receipt.blockNumber,
          status: 'success' as const,
        };
      }, 'Accept P2P Challenge');

    } catch (error: any) {
      console.error('Failed to accept P2P challenge on-chain:', error);
      throw error;
    } finally {
      setIsRetrying(false);
    }
  };

  return {
    createP2PChallenge,
    acceptP2PChallenge,
    factoryAddress: FACTORY_ADDRESS,
    isRetrying,
  };
}
