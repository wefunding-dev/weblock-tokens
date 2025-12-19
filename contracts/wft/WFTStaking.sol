// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WFTStaking is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable wft;

    uint256 public totalStaked;
    mapping(address => uint256) public staked;

    // reward accounting (single reward token version for clarity)
    IERC20 public rewardToken;
    uint256 public accRewardPerShare; // 1e18
    mapping(address => uint256) public rewardDebt;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardDeposited(address indexed from, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    constructor(address wftToken, address admin, address _rewardToken) {
        wft = IERC20(wftToken);
        rewardToken = IERC20(_rewardToken);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function setRewardToken(address _rewardToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardToken = IERC20(_rewardToken);
    }

    function depositReward(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        require(totalStaked > 0, "no stakers");
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        accRewardPerShare += (amount * 1e18) / totalStaked;
        emit RewardDeposited(msg.sender, amount);
    }

    function pendingReward(address user) public view returns (uint256) {
        uint256 userStaked = staked[user];
        if (userStaked == 0) return 0;
        uint256 accumulated = (userStaked * accRewardPerShare) / 1e18;
        if (accumulated <= rewardDebt[user]) return 0;
        return accumulated - rewardDebt[user];
    }

    function stake(uint256 amount) external nonReentrant {
        _claim(msg.sender);

        require(wft.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        staked[msg.sender] += amount;
        totalStaked += amount;

        rewardDebt[msg.sender] = (staked[msg.sender] * accRewardPerShare) / 1e18;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        _claim(msg.sender);

        require(staked[msg.sender] >= amount, "insufficient stake");
        staked[msg.sender] -= amount;
        totalStaked -= amount;

        rewardDebt[msg.sender] = (staked[msg.sender] * accRewardPerShare) / 1e18;

        require(wft.transfer(msg.sender, amount), "transfer failed");
        emit Unstaked(msg.sender, amount);
    }

    function claim() external nonReentrant {
        _claim(msg.sender);
        rewardDebt[msg.sender] = (staked[msg.sender] * accRewardPerShare) / 1e18;
    }

    function _claim(address user) internal {
        uint256 p = pendingReward(user);
        if (p > 0) {
            require(rewardToken.transfer(user, p), "reward transfer failed");
            emit Claimed(user, p);
        }
    }
}
