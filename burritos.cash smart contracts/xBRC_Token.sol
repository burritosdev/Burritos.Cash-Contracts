// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts@4.0.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.0.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.0.0/access/AccessControl.sol";


contract xBRC is ERC20, Ownable, AccessControl {
   bytes32 public constant MINTER_BURNER_ROLE = keccak256("MINTER_BURNER_ROLE");


   // Mapping to track whitelisted staking pool addresses
   mapping(address => bool) private whitelistedPools;


   constructor() ERC20("Staked Burritos Receipt", "xBRC") {
       _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
       _setupRole(MINTER_BURNER_ROLE, msg.sender);
   }


   // Override the transfer function to allow transfers from whitelisted pools or back to the sender
function transfer(address to, uint256 amount) public override returns (bool) {
   require(
       to == msg.sender ||
       whitelistedPools[to] ||
       whitelistedPools[msg.sender],
       "xBRC: Transfer to non-whitelisted address prohibited"
   );
   return super.transfer(to, amount);
   }


   // Override the transferFrom function similarly
   function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
   require(
       to == msg.sender ||
       whitelistedPools[to] ||
       whitelistedPools[from],
       "xBRC: Transfer to non-whitelisted address prohibited"
   );
   return super.transferFrom(from, to, amount);
   }




   // Function to whitelist staking pool addresses
   function addWhitelistedPool(address _pool) external onlyOwner {
       whitelistedPools[_pool] = true;
   }


   // Function to remove from whitelist
   function removeWhitelistedPool(address _pool) external onlyOwner {
       whitelistedPools[_pool] = false;
   }


   // Modified mint function with role check
   function mint(address to, uint256 amount) public {
       require(hasRole(MINTER_BURNER_ROLE, msg.sender), "Must have minter/burner role to mint");
       _mint(to, amount);
   }


   // Modified burn function with role check
   function burn(address from, uint256 amount) public {
       require(hasRole(MINTER_BURNER_ROLE, msg.sender), "Must have minter/burner role to burn");
       _burn(from, amount);
   }


   // Function to grant the minter/burner role to a new account
   function grantMinterBurnerRole(address account) public {
       require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
       grantRole(MINTER_BURNER_ROLE, account);
   }


   // Function to revoke the minter/burner role from an account
   function revokeMinterBurnerRole(address account) public {
       require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
       revokeRole(MINTER_BURNER_ROLE, account);
   }



}
