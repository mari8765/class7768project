// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BantahPoints.sol";

/**
 * @title PointsEscrow
 * @dev Escrow contract for locking/managing points during challenges
 * Allows ChallengeFactory to lock, release, and transfer points between users
 */
contract PointsEscrow is ReentrancyGuard, Ownable {
    
    BantahPoints public pointsToken;
    address public challengeFactory;  // Only this contract can manage escrow
    
    struct LockedPoints {
        uint256 amount;
        uint256 lockedAt;
        uint256 challengeId;
        string reason;
    }
    
    // Mappings
    mapping(address => LockedPoints[]) public userLockedPoints;
    mapping(address => uint256) public totalLockedPoints;
    mapping(uint256 => address[]) public challengeParticipants;
    
    // Events
    event PointsLocked(
        address indexed user,
        uint256 amount,
        uint256 indexed challengeId,
        string reason
    );
    
    event PointsReleased(
        address indexed user,
        uint256 amount,
        uint256 indexed challengeId
    );
    
    event PointsTransferred(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed challengeId,
        string reason
    );
    
    event ChallengeFactoryUpdated(address indexed newFactory);
    
    // Modifiers
    modifier onlyChallengeFactory() {
        require(msg.sender == challengeFactory, "Only ChallengeFactory");
        _;
    }
    
    // Constructor
    constructor(address _pointsToken, address _challengeFactory) Ownable(msg.sender) {
        require(_pointsToken != address(0), "Invalid points token");
        require(_challengeFactory != address(0), "Invalid factory");
        pointsToken = BantahPoints(_pointsToken);
        challengeFactory = _challengeFactory;
    }
    
    /**
     * @dev Lock points as stakes for a challenge
     * Called by ChallengeFactory when user joins challenge
     */
    function lockPoints(
        address user,
        uint256 amount,
        uint256 challengeId,
        string calldata reason
    ) external onlyChallengeFactory nonReentrant {
        require(user != address(0), "Invalid user");
        require(amount > 0, "Amount must be > 0");
        
        // Burn points from user (simulate locking)
        pointsToken.burnPointsFrom(user, amount);
        
        // Record locked points
        userLockedPoints[user].push(LockedPoints({
            amount: amount,
            lockedAt: block.timestamp,
            challengeId: challengeId,
            reason: reason
        }));
        
        totalLockedPoints[user] += amount;
        
        // Track participants
        challengeParticipants[challengeId].push(user);
        
        emit PointsLocked(user, amount, challengeId, reason);
    }
    
    /**
     * @dev Release locked points back to user (on loss)
     */
    function releasePoints(
        address user,
        uint256 amount,
        uint256 challengeId
    ) external onlyChallengeFactory nonReentrant {
        require(user != address(0), "Invalid user");
        require(amount > 0, "Amount must be > 0");
        require(totalLockedPoints[user] >= amount, "Insufficient locked points");
        
        // Remove from locked points
        totalLockedPoints[user] -= amount;
        
        // Award points back to user
        pointsToken.awardPoints(user, amount, challengeId, "locked_points_released");
        
        emit PointsReleased(user, amount, challengeId);
    }
    
    /**
     * @dev Transfer locked points from loser to winner
     */
    function transferLockedPoints(
        address loser,
        address winner,
        uint256 amount,
        uint256 challengeId
    ) external onlyChallengeFactory nonReentrant {
        require(loser != address(0), "Invalid loser");
        require(winner != address(0), "Invalid winner");
        require(amount > 0, "Amount must be > 0");
        require(totalLockedPoints[loser] >= amount, "Insufficient locked points");
        
        // Remove from loser
        totalLockedPoints[loser] -= amount;
        
        // Award to winner
        pointsToken.awardPoints(winner, amount, challengeId, "challenge_winnings");
        
        emit PointsTransferred(loser, winner, amount, challengeId, "challenge_winnings");
    }
    
    /**
     * @dev Get total locked points for a user
     */
    function getTotalLockedPoints(address user) external view returns (uint256) {
        return totalLockedPoints[user];
    }
    
    /**
     * @dev Get locked points entries for a user
     */
    function getUserLockedPoints(address user) external view returns (LockedPoints[] memory) {
        return userLockedPoints[user];
    }
    
    /**
     * @dev Get challenge participants who had points locked
     */
    function getChallengeParticipants(uint256 challengeId) external view returns (address[] memory) {
        return challengeParticipants[challengeId];
    }
    
    /**
     * @dev Update ChallengeFactory address (in case of upgrade)
     */
    function setChallengeFactory(address newFactory) external onlyOwner {
        require(newFactory != address(0), "Invalid factory");
        challengeFactory = newFactory;
        emit ChallengeFactoryUpdated(newFactory);
    }
    
    /**
     * @dev Clear old locked points entries (maintenance)
     * Only callable by owner, helps with storage optimization
     */
    function clearExpiredLocks(address user) external onlyOwner {
        require(user != address(0), "Invalid user");
        
        LockedPoints[] storage locks = userLockedPoints[user];
        uint256 oneYear = 365 days;
        
        for (uint256 i = 0; i < locks.length; i++) {
            // Clear locks older than 1 year
            if (block.timestamp - locks[i].lockedAt > oneYear) {
                locks[i] = locks[locks.length - 1];
                locks.pop();
            }
        }
    }
}
