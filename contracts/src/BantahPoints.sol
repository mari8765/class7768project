// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BantahPoints
 * @dev ERC-20 token representing Bantah user points/reputation
 * Can be earned through challenges, burned, and traded
 */
contract BantahPoints is ERC20, ERC20Burnable, Ownable {
    
    // Admin address who can mint points (ChallengeFactory contract)
    address public pointsManager;
    
    // Track points balance per user (for display purposes)
    mapping(address => uint256) public userPointsBalance;
    
    // Track total points awarded per challenge
    mapping(uint256 => uint256) public challengePointsAwarded;
    
    // Events
    event PointsAwarded(address indexed user, uint256 amount, uint256 indexed challengeId, string reason);
    event PointsBurned(address indexed user, uint256 amount);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event PointsManagerUpdated(address indexed newManager);
    
    constructor() ERC20("Bantah Points", "BPTS") Ownable(msg.sender) {
        pointsManager = msg.sender;
        // Initial supply: 1 million points (18 decimals)
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
    
    /**
     * @dev Award points to a user for challenge participation
     * Only callable by points manager (ChallengeFactory)
     */
    function awardPoints(
        address user,
        uint256 amount,
        uint256 challengeId,
        string calldata reason
    ) external onlyPointsManager {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be > 0");
        
        // Mint new points
        _mint(user, amount);
        
        // Update tracking
        userPointsBalance[user] += amount;
        challengePointsAwarded[challengeId] += amount;
        
        emit PointsAwarded(user, amount, challengeId, reason);
    }
    
    /**
     * @dev Burn points from a user's balance
     * Called when points are used for something
     */
    function burnPointsFrom(address user, uint256 amount) external onlyPointsManager {
        require(balanceOf(user) >= amount, "Insufficient points balance");
        
        _burn(user, amount);
        userPointsBalance[user] -= amount;
        
        emit PointsBurned(user, amount);
    }
    
    /**
     * @dev Transfer points between users
     */
    function transferPoints(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Invalid recipient");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _transfer(msg.sender, to, amount);
        
        emit PointsTransferred(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev Set the points manager address
     * Only owner can call this
     */
    function setPointsManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Invalid manager address");
        pointsManager = newManager;
        emit PointsManagerUpdated(newManager);
    }
    
    /**
     * @dev Get user's current points balance
     */
    function getUserPointsBalance(address user) external view returns (uint256) {
        return userPointsBalance[user];
    }
    
    /**
     * @dev Get total points awarded for a challenge
     */
    function getChallengePoints(uint256 challengeId) external view returns (uint256) {
        return challengePointsAwarded[challengeId];
    }
    
    /**
     * @dev Modifier: Only points manager can call
     */
    modifier onlyPointsManager() {
        require(msg.sender == pointsManager, "Only points manager");
        _;
    }
}
