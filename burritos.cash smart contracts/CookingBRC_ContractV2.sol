Contract Address: 0x916DeFC09E19004F00527B955c7Fe6ff31cE9eD5


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts@4.0.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.0.0/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.0.0/access/Ownable.sol";


interface IBurritosToken is IERC20 {
   function mint(address account, uint256 amount) external;
}


interface IxBRC is IERC20 {
   function mint(address account, uint256 amount) external;
   function burn(address account, uint256 amount) external;
}


contract BurritosStaking is ReentrancyGuard, Ownable {
   IBurritosToken public burritosToken;
   IxBRC public xBRCToken; // xBRC token interface


   struct Stake {
       uint256 amount;
       uint256 since;
   }


   struct APRChange {
       uint256 newAPR;
       uint256 timestamp;
   }


   mapping(address => Stake) public stakes;
   uint256 public apr = 36900; // APR in basis points
   APRChange[] public aprChanges;
   uint256 private totalStakedBRC; // Total BRC staked in the contract


   event Staked(address indexed user, uint256 amount, uint256 since);
   event Unstaked(address indexed user, uint256 amount);
   event RewardClaimed(address indexed user, uint256 reward);


   constructor(IBurritosToken _burritosToken, IxBRC _xBRCToken) {
       burritosToken = _burritosToken;
       xBRCToken = _xBRCToken;
       aprChanges.push(APRChange({newAPR: apr, timestamp: block.timestamp}));
   }


   function stake(uint256 amount) external nonReentrant {
       require(amount > 0, "Cannot stake 0 tokens");
       require(burritosToken.balanceOf(msg.sender) >= amount, "Insufficient balance to stake");


       burritosToken.transferFrom(msg.sender, address(this), amount);
       xBRCToken.mint(msg.sender, amount); // Mint xBRC tokens to the staker


       stakes[msg.sender].amount += amount;
       stakes[msg.sender].since = block.timestamp;
       totalStakedBRC += amount; // Update the total staked BRC


       emit Staked(msg.sender, amount, block.timestamp);
   }


   function unstake(uint256 amount) external nonReentrant {
       require(amount > 0, "Amount must be greater than 0");
       uint256 stakedAmount = stakes[msg.sender].amount;
       require(stakedAmount >= amount, "Insufficient staked amount");


       uint256 reward = calculateReward(msg.sender);


       stakes[msg.sender].amount -= amount;
       totalStakedBRC -= amount; // Update the total staked BRC
       xBRCToken.burn(msg.sender, amount); // Burn the corresponding xBRC tokens


       if (stakes[msg.sender].amount == 0) {
           stakes[msg.sender].since = 0;
       }


       burritosToken.transfer(msg.sender, amount);
       if (reward > 0) {
           mintReward(msg.sender, reward);
           emit RewardClaimed(msg.sender, reward);
       }


       emit Unstaked(msg.sender, amount);
   }


   function calculateReward(address user) public view returns (uint256) {
       Stake memory userStake = stakes[user];
       if (userStake.amount == 0) {
           return 0;
       }


       uint256 totalReward = 0;
       uint256 lastTimestamp = userStake.since;
       uint256 currentAPR = aprChanges[0].newAPR; // Start with the initial APR


       for (uint256 i = 0; i < aprChanges.length; i++) {
           APRChange memory change = aprChanges[i];


           // Check if the APR change is within the staking period
           if (change.timestamp > lastTimestamp && change.timestamp <= block.timestamp) {
               totalReward += calculateSegmentReward(userStake.amount, lastTimestamp, change.timestamp, currentAPR);
               lastTimestamp = change.timestamp;
           }
           currentAPR = change.newAPR;
       }


       // Calculate reward for the final segment
       totalReward += calculateSegmentReward(userStake.amount, lastTimestamp, block.timestamp, currentAPR);
       return totalReward;
   }


   function calculateSegmentReward(uint256 amount, uint256 start, uint256 end, uint256 segmentAPR) internal pure returns (uint256) {
       uint256 duration = end - start;
       uint256 yearlyReward = (amount * segmentAPR) / 10000; // APR is in basis points
       return (yearlyReward * duration) / 365 days;
   }


   function claimReward() external nonReentrant {
       uint256 reward = calculateReward(msg.sender);
       require(reward > 0, "No reward available");


       mintReward(msg.sender, reward);


       // Reset the stake's `since` to the current time
       stakes[msg.sender].since = block.timestamp;
       emit RewardClaimed(msg.sender, reward);
   }


   function mintReward(address user, uint256 reward) internal {
       burritosToken.mint(user, reward);
   }


   function setAPR(uint256 _apr) external onlyOwner {
       require(_apr > 0, "APR must be greater than 0");
       aprChanges.push(APRChange({newAPR: _apr, timestamp: block.timestamp}));
       apr = _apr;
   }


   // Function to get the total BRC staked in the contract
   function getTotalStakedBRC() external view returns (uint256) {
       return totalStakedBRC;
   }


   // Add this function inside your BurritosStaking contract
   function getBRCAllowance(address user) public view returns (uint256) {
   return burritosToken.allowance(user, address(this));
   }


   // Function to renounce ownership of the contract
   function renounceContractOwnership() public onlyOwner {
   renounceOwnership();
   }




}
