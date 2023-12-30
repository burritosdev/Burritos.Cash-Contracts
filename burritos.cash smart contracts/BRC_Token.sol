// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts@4.0.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.0.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.0.0/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.0.0/access/AccessControl.sol";


contract Burritos is IERC20, Ownable, ReentrancyGuard, AccessControl {
  string public constant name = "Burritos.Cash";
  string public constant symbol = "BRC";
  uint8 public constant decimals = 18;


  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


  uint256 public constant TokenPrice = 1 * (10 ** uint256(decimals));
  uint256 public constant PLSMintingCap = 36900000 * (10 ** uint256(decimals));
  uint256 public constant MaxSupply = 36900000000 * (10 ** uint256(decimals));
   uint256 private _totalSupply; // Private variable for total supply
  uint256 public brcMintedWithPLS; // New variable to track BRC minted with PLS


  mapping(address => uint256) private balances;
  mapping(address => mapping(address => uint256)) private allowed;


  IERC20 public plsToken;
  address private constant plsTokenAddress = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
  address private feesAddress;


  constructor() {
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
      plsToken = IERC20(plsTokenAddress);
      feesAddress = (insert here);
  }


  function totalSupply() public view override returns (uint256) {
      return _totalSupply;
  }


  function mintBurritos(uint256 plsAmount) external nonReentrant {
      require(plsAmount % TokenPrice == 0, "Send a multiple of the price");
      uint256 burritosAmount = (plsAmount / TokenPrice) * 369 / 100000 * (10 ** uint256(decimals));
      require(_totalSupply + burritosAmount <= PLSMintingCap, "PLS minting cap exceeded");
      require(_totalSupply + burritosAmount <= MaxSupply, "Max supply exceeded");


      plsToken.transferFrom(msg.sender, feesAddress, plsAmount);
      _mint(msg.sender, burritosAmount);
      brcMintedWithPLS += burritosAmount; // Update the counter for BRC minted with PLS
  }


  function mint(address to, uint256 amount) public {
      require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
      _mint(to, amount);
  }


  function _mint(address account, uint256 amount) internal {
      require(account != address(0), "Mint to the zero address");
      require(_totalSupply + amount <= MaxSupply, "Max supply exceeded");


      _totalSupply += amount;
      balances[account] += amount;
      emit Transfer(address(0), account, amount);
  }


  function balanceOf(address account) public view override returns (uint256) {
      return balances[account];
  }


  function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
      require(balances[msg.sender] >= amount, "Not enough tokens");
      balances[msg.sender] -= amount;
      balances[recipient] += amount;
      emit Transfer(msg.sender, recipient, amount);
      return true;
  }


  function approve(address spender, uint256 amount) public override returns (bool) {
      require(spender != address(0), "Approve to the zero address");
      allowed[msg.sender][spender] = amount;
      emit Approval(msg.sender, spender, amount);
      return true;
  }


  function transferFrom(address sender, address recipient, uint256 amount) public override nonReentrant returns (bool) {
      require(amount <= balances[sender], "Insufficient balance");
      require(amount <= allowed[sender][msg.sender], "Insufficient allowance");


      balances[sender] -= amount;
      balances[recipient] += amount;
      allowed[sender][msg.sender] -= amount;
      emit Transfer(sender, recipient, amount);
      return true;
  }


  function allowance(address owner, address spender) public view override returns (uint256) {
      return allowed[owner][spender];
  }


  function setFeesAddress(address _newFeesAddress) external onlyOwner {
      feesAddress = _newFeesAddress;
  }


  // Additional functions as needed for Access Control
}
