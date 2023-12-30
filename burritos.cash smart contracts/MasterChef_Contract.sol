// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/access/Ownable.sol";
import "./SalsaTokenContractV1.sol";


contract MasterChef is Ownable, ReentrancyGuard {
   using SafeERC20 for IERC20;


   // Info of each user.
   struct UserInfo {
       uint256 amount; // How many LP tokens the user has provided.
       uint256 rewardDebt; // Reward debt.
   }


   // Info of each pool.
   struct PoolInfo {
       IERC20 lpToken; // Address of LP token contract.
       uint256 allocPoint; // How many allocation points assigned to this pool.
       uint256 lastRewardBlock; // Last block number that Salsa distribution occurs.
       uint256 accSalsaPerShare; // Accumulated Salsa per share, times 1e12.
       uint16 depositFeeBP; // Deposit fee in basis points.
       uint16 withdrawFeeBP; // Withdrawal fee in basis points.
   }


   // The Salsa Token!
   SalsaToken public salsa;
   // Developer address.
   address public devAddress;
   // Deposit Fee address
   address public feeAddress;
   // Salsa tokens created per block.
   uint256 public salsaPerBlock;
   // Maximum emission rate
   uint256 public constant MAX_EMISSION_RATE = 10**24;


   // Info of each pool.
   PoolInfo[] public poolInfo;
   // Info of each user that stakes LP tokens.
   mapping(uint256 => mapping(address => UserInfo)) public userInfo;
   // Total allocation points. Must be the sum of all allocation points in all pools.
   uint256 public totalAllocPoint = 0;
   // The block number when SALSA mining starts.
   uint256 public startBlock;


   event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
   event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
   event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
   event SetDevAddress(address indexed oldAddress, address indexed newAddress);
   event SetFeeAddress(address indexed oldAddress, address indexed newAddress);
   event UpdateEmissionRate(address indexed user, uint256 salsaPerBlock);


   constructor(
       SalsaToken _salsa,
       address _devAddress,
       address _feeAddress,
       uint256 _salsaPerBlock,
       uint256 _startBlock
   ) {
       salsa = _salsa;
       devAddress = _devAddress;
       feeAddress = _feeAddress;
       salsaPerBlock = _salsaPerBlock;
       startBlock = _startBlock;
   }


   function poolLength() external view returns (uint256) {
       return poolInfo.length;
   }


   // Add a new lp to the pool. Can only be called by the owner.
   function add(
       uint256 _allocPoint,
       IERC20 _lpToken,
       uint16 _depositFeeBP,
       uint16 _withdrawFeeBP,
       bool _withUpdate
   ) public onlyOwner {
       require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
       require(_withdrawFeeBP <= 10000, "add: invalid withdraw fee basis points");
       if (_withUpdate) {
           massUpdatePools();
       }
       uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
       totalAllocPoint += _allocPoint;
       poolInfo.push(
           PoolInfo({
               lpToken: _lpToken,
               allocPoint: _allocPoint,
               lastRewardBlock: lastRewardBlock,
               accSalsaPerShare: 0,
               depositFeeBP: _depositFeeBP,
               withdrawFeeBP: _withdrawFeeBP
           })
       );
   }


   // Update the given pool's SALSA allocation point. Can only be called by the owner.
   function set(
       uint256 _pid,
       uint256 _allocPoint,
       uint16 _depositFeeBP,
       uint16 _withdrawFeeBP,
       bool _withUpdate
   ) public onlyOwner {
       require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
       require(_withdrawFeeBP <= 10000, "set: invalid withdraw fee basis points");
       if (_withUpdate) {
           massUpdatePools();
       }
       totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
       poolInfo[_pid].allocPoint = _allocPoint;
       poolInfo[_pid].depositFeeBP = _depositFeeBP;
       poolInfo[_pid].withdrawFeeBP = _withdrawFeeBP;
   }


   // Return reward multiplier over the given _from to _to block.
   function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
       return _to - _from;
   }


   // View function to see pending SALSA on frontend.
   function pendingSalsa(uint256 _pid, address _user) external view returns (uint256) {
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][_user];
       uint256 accSalsaPerShare = pool.accSalsaPerShare;
       uint256 lpSupply = pool.lpToken.balanceOf(address(this));
       if (block.number > pool.lastRewardBlock && lpSupply != 0) {
           uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
           uint256 salsaReward = multiplier * salsaPerBlock * pool.allocPoint / totalAllocPoint;
           accSalsaPerShare += salsaReward * 1e12 / lpSupply;
       }
       return user.amount * accSalsaPerShare / 1e12 - user.rewardDebt;
   }


   // Update reward variables for all pools. Be careful of gas spending!
   function massUpdatePools() public {
       uint256 length = poolInfo.length;
       for (uint256 pid = 0; pid < length; ++pid) {
           updatePool(pid);
       }
   }


   // Update reward variables of the given pool to be up-to-date.
   function updatePool(uint256 _pid) public {
       PoolInfo storage pool = poolInfo[_pid];
       if (block.number <= pool.lastRewardBlock) {
           return;
       }
       uint256 lpSupply = pool.lpToken.balanceOf(address(this));
       if (lpSupply == 0 || pool.allocPoint == 0) {
           pool.lastRewardBlock = block.number;
           return;
       }
       uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
       uint256 salsaReward = multiplier * salsaPerBlock * pool.allocPoint / totalAllocPoint;
       salsa.mint(devAddress, salsaReward / 10);
       salsa.mint(address(this), salsaReward);
       pool.accSalsaPerShare += salsaReward * 1e12 / lpSupply;
       pool.lastRewardBlock = block.number;
   }


   // Deposit LP tokens to MasterChef.
   function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][msg.sender];
       updatePool(_pid);
       if (user.amount > 0) {
           uint256 pending = user.amount * pool.accSalsaPerShare / 1e12 - user.rewardDebt;
           if (pending > 0) {
               safeSalsaTransfer(msg.sender, pending);
           }
       }
       if (_amount > 0) {
           pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
           if (pool.depositFeeBP > 0) {
               uint256 depositFee = _amount * pool.depositFeeBP / 10000;
               pool.lpToken.safeTransfer(feeAddress, depositFee);
               user.amount += _amount - depositFee;
           } else {
               user.amount += _amount;
           }
       }
       user.rewardDebt = user.amount * pool.accSalsaPerShare / 1e12;
       emit Deposit(msg.sender, _pid, _amount);
   }


   // Modified withdraw function with withdraw fee
   function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][msg.sender];
       require(user.amount >= _amount, "withdraw: not good");
       updatePool(_pid);
       uint256 pending = user.amount * pool.accSalsaPerShare / 1e12 - user.rewardDebt;
       if (pending > 0) {
           safeSalsaTransfer(msg.sender, pending);
       }
       if (_amount > 0) {
           uint256 withdrawFee = _amount * pool.withdrawFeeBP / 10000;
           user.amount -= _amount;
           _amount -= withdrawFee;
           pool.lpToken.safeTransfer(address(msg.sender), _amount);
           pool.lpToken.safeTransfer(feeAddress, withdrawFee);
       }
       user.rewardDebt = user.amount * pool.accSalsaPerShare / 1e12;
       emit Withdraw(msg.sender, _pid, _amount);
   }


   // Withdraw without caring about rewards. EMERGENCY ONLY.
   function emergencyWithdraw(uint256 _pid) public nonReentrant {
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][msg.sender];
       uint256 amount = user.amount;
       user.amount = 0;
       user.rewardDebt = 0;
       pool.lpToken.safeTransfer(address(msg.sender), amount);
       emit EmergencyWithdraw(msg.sender, _pid, amount);
   }


   // Get user-specific details for a pool, including staked tokens and pending rewards
   function getUserPoolInfo(uint256 _pid, address _user) external view returns (uint256 stakedAmount, uint256 pendingRewards) {
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][_user];
       stakedAmount = user.amount;


       uint256 accSalsaPerShare = pool.accSalsaPerShare;
       uint256 lpSupply = pool.lpToken.balanceOf(address(this));


       if (block.number > pool.lastRewardBlock && lpSupply != 0) {
           uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
           uint256 salsaReward = multiplier * salsaPerBlock * pool.allocPoint / totalAllocPoint;
           accSalsaPerShare += salsaReward * 1e12 / lpSupply;
       }
       pendingRewards = user.amount * accSalsaPerShare / 1e12 - user.rewardDebt;
   }


   // Get total staked tokens in a specific pool
   function getTotalStaked(uint256 _pid) external view returns (uint256) {
       PoolInfo storage pool = poolInfo[_pid];
       return pool.lpToken.balanceOf(address(this));
   }


   // Harvest SALSA rewards
   function harvest(uint256 _pid) public nonReentrant {
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][msg.sender];
       updatePool(_pid);
       uint256 pending = (user.amount * pool.accSalsaPerShare / 1e12) - user.rewardDebt;
       if (pending > 0) {
           safeSalsaTransfer(msg.sender, pending);
       }
       user.rewardDebt = user.amount * pool.accSalsaPerShare / 1e12;
       emit Harvest(msg.sender, _pid, pending);
   }


event Harvest(address indexed user, uint256 indexed pid, uint256 amount);


   // Safe salsa transfer function, just in case if rounding error causes pool to not have enough SALSA.
   function safeSalsaTransfer(address _to, uint256 _amount) internal {
       uint256 salsaBal = salsa.balanceOf(address(this));
       if (_amount > salsaBal) {
           salsa.transfer(_to, salsaBal);
       } else {
           salsa.transfer(_to, _amount);
       }
   }


   // Update dev address.
   function setDevAddress(address _devAddress) public {
       require(msg.sender == devAddress, "setDevAddress: FORBIDDEN");
       require(_devAddress != address(0), "setDevAddress: ZERO");
       emit SetDevAddress(devAddress, _devAddress);
       devAddress = _devAddress;
   }


   // Update fee address.
   function setFeeAddress(address _feeAddress) public {
       require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
       require(_feeAddress != address(0), "setFeeAddress: ZERO");
       emit SetFeeAddress(feeAddress, _feeAddress);
       feeAddress = _feeAddress;
   }


   // Update emission rate.
   function updateEmissionRate(uint256 _salsaPerBlock) public onlyOwner {
       require(_salsaPerBlock <= MAX_EMISSION_RATE, "updateEmissionRate: too high");
       massUpdatePools();
       emit UpdateEmissionRate(msg.sender, _salsaPerBlock);
       salsaPerBlock = _salsaPerBlock;
   }


   // Function to check approval balance
   function getApprovalBalance(IERC20 _token, address _owner) external view returns (uint256) {
       return _token.allowance(_owner, address(this));
   }
}


