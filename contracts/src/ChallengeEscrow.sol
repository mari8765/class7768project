// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChallengeEscrow
 * @dev Holds ERC20 token stakes for challenges (USDC, USDT, etc.)
 * Manages locking, releasing, and transferring stakes between users
 */
contract ChallengeEscrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    address public challengeFactory;  // Only this contract can manage escrow
    
    struct LockedStake {
        address token;           // ERC20 token address
        uint256 amount;
        uint256 lockedAt;
        uint256 challengeId;
        bool released;
    }
    
    // Mappings
    mapping(address => mapping(address => uint256)) public totalLockedByToken;  // user => token => amount
    mapping(uint256 => address[]) public challengeParticipants;
    mapping(uint256 => LockedStake[]) public challengeStakes;
    
    // Events
    event StakeLocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 indexed challengeId
    );
    
    event StakeReleased(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 indexed challengeId
    );
    
    event StakeTransferred(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 challengeId,
        string reason
    );
    
    event ChallengeFactoryUpdated(address indexed newFactory);
    
    // Constructor
    constructor(address _challengeFactory) Ownable(msg.sender) {
        require(_challengeFactory != address(0), "Invalid factory");
        challengeFactory = _challengeFactory;
    }
    
    // Modifiers
    modifier onlyFactory() {
        require(msg.sender == challengeFactory, "Only ChallengeFactory");
        _;
    }
    
    /**
     * @dev Lock ERC20 token stakes for a challenge
     * Called by ChallengeFactory when user joins challenge
     */
    function lockStake(
        address user,
        address token,
        uint256 amount,
        uint256 challengeId
    ) external onlyFactory nonReentrant {
        require(user != address(0), "Invalid user");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be > 0");
        
        // Transfer tokens from ChallengeFactory (which received them from user) to escrow
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Track locked stake
        LockedStake memory newStake = LockedStake({
            token: token,
            amount: amount,
            lockedAt: block.timestamp,
            challengeId: challengeId,
            released: false
        });
        
        challengeStakes[challengeId].push(newStake);
        totalLockedByToken[user][token] += amount;
        challengeParticipants[challengeId].push(user);
        
        emit StakeLocked(user, token, amount, challengeId);
    }
    
    /**
     * @dev Release locked stakes (e.g., if challenge is cancelled)
     * Returns tokens to users
     */
    function releaseStakes(uint256 challengeId, address[] calldata users) external onlyFactory nonReentrant {
        LockedStake[] storage stakes = challengeStakes[challengeId];
        
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            
            for (uint256 j = 0; j < stakes.length; j++) {
                LockedStake storage stake = stakes[j];
                
                if (!stake.released) {
                    // Return stake to user
                    IERC20(stake.token).safeTransfer(user, stake.amount);
                    totalLockedByToken[user][stake.token] -= stake.amount;
                    stake.released = true;
                    
                    emit StakeReleased(user, stake.token, stake.amount, challengeId);
                }
            }
        }
    }
    
    /**
     * @dev Transfer stakes from loser to winner
     * Called by ChallengeFactory when challenge is resolved
     */
    function transferStake(
        address from,
        address to,
        address token,
        uint256 amount,
        uint256 challengeId
    ) external onlyFactory nonReentrant {
        require(from != address(0), "Invalid from");
        require(to != address(0), "Invalid to");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be > 0");
        
        // Transfer tokens from escrow to winner
        IERC20(token).safeTransfer(to, amount);
        
        // Update tracking
        totalLockedByToken[from][token] -= amount;
        
        emit StakeTransferred(from, to, token, amount, challengeId, "Challenge settlement");
    }
    
    /**
     * @dev Get total locked amount for user by token
     */
    function getTotalLockedByToken(address user, address token) external view returns (uint256) {
        return totalLockedByToken[user][token];
    }
    
    /**
     * @dev Get all stakes for a challenge
     */
    function getChallengeStakes(uint256 challengeId) external view returns (LockedStake[] memory) {
        return challengeStakes[challengeId];
    }
    
    /**
     * @dev Get challenge participants
     */
    function getChallengeParticipants(uint256 challengeId) external view returns (address[] memory) {
        return challengeParticipants[challengeId];
    }
    
    /**
     * @dev Update challenge factory address
     */
    function setChallengeFactory(address _newFactory) external onlyOwner {
        require(_newFactory != address(0), "Invalid factory");
        challengeFactory = _newFactory;
        emit ChallengeFactoryUpdated(_newFactory);
    }
}
