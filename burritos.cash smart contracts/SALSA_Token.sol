// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/access/Ownable.sol";


contract SalsaToken is ERC20, Ownable {
   mapping(address => bool) private minters;


   event MinterAdded(address indexed newMinter);
   event MinterRemoved(address indexed minter);


   constructor() ERC20('Salsa from Burritos.Cash', 'SALSA') {
       minters[msg.sender] = true;
   }


   function addMinter(address _minter) public onlyOwner {
       minters[_minter] = true;
       emit MinterAdded(_minter);
   }


   function removeMinter(address _minter) public onlyOwner {
       minters[_minter] = false;
       emit MinterRemoved(_minter);
   }


   function mint(address to, uint256 amount) public {
       require(minters[msg.sender], "Not a minter");
       _mint(to, amount);
   }


   // Rest of your existing SalsaToken code follows below...
   mapping (address => address) internal _delegates;


   struct Checkpoint {
       uint32 fromBlock;
       uint256 votes;
   }


   mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;
   mapping (address => uint32) public numCheckpoints;


   bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
   bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");


   mapping (address => uint) public nonces;


   event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
   event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);


   function delegates(address delegator) external view returns (address) {
       return _delegates[delegator];
   }


   function delegate(address delegatee) external {
       return _delegate(msg.sender, delegatee);
   }


   function delegateBySig(
       address delegatee,
       uint nonce,
       uint expiry,
       uint8 v,
       bytes32 r,
       bytes32 s
   ) external {
       bytes32 domainSeparator = keccak256(
           abi.encode(
               DOMAIN_TYPEHASH,
               keccak256(bytes(name())),
               getChainId(),
               address(this)
           )
       );


       bytes32 structHash = keccak256(
           abi.encode(
               DELEGATION_TYPEHASH,
               delegatee,
               nonce,
               expiry
           )
       );


       bytes32 digest = keccak256(
           abi.encodePacked(
               "\x19\x01",
               domainSeparator,
               structHash
           )
       );


       address signatory = ecrecover(digest, v, r, s);
       require(signatory != address(0), "SALSA::delegateBySig: invalid signature");
       require(nonce == nonces[signatory]++, "SALSA::delegateBySig: invalid nonce");
       require(block.timestamp <= expiry, "SALSA::delegateBySig: signature expired");


       return _delegate(signatory, delegatee);
   }


   function getCurrentVotes(address account) external view returns (uint256) {
       uint32 nCheckpoints = numCheckpoints[account];
       return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
   }


   function getPriorVotes(address account, uint blockNumber) external view returns (uint256) {
       require(blockNumber < block.number, "SALSA::getPriorVotes: not yet determined");


       uint32 nCheckpoints = numCheckpoints[account];
       if (nCheckpoints == 0) return 0;


       if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
           return checkpoints[account][nCheckpoints - 1].votes;
       }


       if (checkpoints[account][0].fromBlock > blockNumber) return 0;


       uint32 lower = 0;
       uint32 upper = nCheckpoints - 1;
       while (upper > lower) {
           uint32 center = upper - (upper - lower) / 2;
           Checkpoint memory cp = checkpoints[account][center];
           if (cp.fromBlock == blockNumber) {
               return cp.votes;
           } else if (cp.fromBlock < blockNumber) {
               lower = center;
           } else {
               upper = center - 1;
           }
       }
       return checkpoints[account][lower].votes;
   }


   function _delegate(address delegator, address delegatee) internal {
       address currentDelegate = _delegates[delegator];
       uint256 delegatorBalance = balanceOf(delegator);
       _delegates[delegator] = delegatee;


       emit DelegateChanged(delegator, currentDelegate, delegatee);
       _moveDelegates(currentDelegate, delegatee, delegatorBalance);
   }


   function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
       if (srcRep != dstRep && amount > 0) {
           if (srcRep != address(0)) {
               uint32 srcRepNum = numCheckpoints[srcRep];
               uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
               uint256 srcRepNew = srcRepOld - amount;
               _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
           }


           if (dstRep != address(0)) {
               uint32 dstRepNum = numCheckpoints[dstRep];
               uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
               uint256 dstRepNew = dstRepOld + amount;
               _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
           }
       }
   }


   function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
       uint32 blockNumber = safe32(block.number, "SALSA::_writeCheckpoint: block number exceeds 32 bits");


       if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
           checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
       } else {
           checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
           numCheckpoints[delegatee] = nCheckpoints + 1;
       }


       emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
   }


   function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
       require(n < 2**32, errorMessage);
       return uint32(n);
   }


   function getChainId() internal view returns (uint) {
       uint256 chainId;
       assembly { chainId := chainid() }
       return chainId;
   }
}


