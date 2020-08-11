pragma solidity ^0.4.26;

contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function safeMul(uint a, uint b) public pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function safeDiv(uint a, uint b) public pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}
/*    Reward is the total Bonus Given to the Refferer .
referrerSet is a flag to ensure weather that address is already reffered or not.
canReferrer is a flag to ensure wheather that address can reffer or not   */

contract pyzusReferral is SafeMath  {
    
    struct Account {
        address referrer;
        uint referredCount;
        uint referredCountIndirect;
        uint reward;
        bool referrerSet;
        bool canReferrer;
    }
    
    
    mapping(address => Account) public accounts;
    
    uint256[] levelRate = [100,50,30,20];
   
    uint decimals = 1000;
  
    uint priceETH = 395;
    
    // Original payzus contract address.
    address payzusAddr;
    // owner Address of payzus contract.
    address owner;
      
    event RegisteredReferer(address referee, address referrer);
    event PaidReferral(address from, address to, uint amount, uint level);
    event BuyTokens(uint value);
    
    constructor (address _payzusAddr, address _owner) public {
        payzusAddr = _payzusAddr;
        owner = _owner;
    }
    
    
// Buy tokens.
    
    function buyTokens(uint _value) public returns (bool){
        
        require(_value != 0, "Tokens must be greater than 0");
        uint price;
        price = safeDiv(safeMul(_value,67 ),1000);
        require (price > 15, "Tokens price must be greater than $15 i.e min. 230 tokens");
        require(price < 500, "Tokens price must be smaller than $500 i.e max 7450 tokens");
    
        accounts[msg.sender].canReferrer = true;
    
        bool success = payzusAddr.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",owner,msg.sender,_value));
          
        payReferral(_value);
        emit BuyTokens(_value);
        return success;
           
    }
    




    function isCircularReference(address referrer, address referee) internal view returns(bool){
        address parent = referrer;
    
        for (uint i; i < levelRate.length; i++) {
          if (parent == address(0)) {
            break;
          }
    
          if (parent == referee) {
            return true;
          }
    
          parent = accounts[parent].referrer;
        }
    
        return false;
      }



   function addReferrer(address referrer) public returns(bool){
       require(referrer != address(0), "Referrer cannot be 0x0 address");
       require( accounts[msg.sender].referrerSet != true, "Referrer already set");
       require( accounts[referrer].canReferrer != false , "Referrer is not eligible.");
       require( isCircularReference(referrer, msg.sender) != true, "Referee cannot be one of referrer uplines");
       require( accounts[msg.sender].referrer == address(0), "Address have been registered upline");
    
        Account storage userAccount = accounts[msg.sender];
        Account storage parentAccount = accounts[referrer];
    
        userAccount.referrer = referrer;
        userAccount.referrerSet = true;
        parentAccount.referredCount = safeAdd(parentAccount.referredCount,1);
        
        for (uint i; i<levelRate.length-1; i++) {
            address parent = parentAccount.referrer;
            Account storage parentAccount2 = accounts[parentAccount.referrer];
    
          if (parent == address(0)) {
            break;
          }
          
          parentAccount2.referredCountIndirect = safeAdd(parentAccount2.referredCountIndirect,1); 
          
          parentAccount = parentAccount2;
                
        }
    
        emit RegisteredReferer(msg.sender, referrer);
        return true;
      }
    
    
    
    function payReferral(uint value) internal returns (bool){
        Account memory userAccount = accounts[msg.sender];
        bool success;

        for (uint i; i < levelRate.length; i++) {
          address parent = userAccount.referrer;
          Account storage parentAccount = accounts[userAccount.referrer];
    
          if (parent == address(0)) {
            break;
          }
    
          
            uint c = (value*levelRate[i])/decimals;
        
            success = payzusAddr.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",owner,parent,c));
            
            parentAccount.reward = parentAccount.reward+c;
          
            emit PaidReferral(msg.sender, parent, c, i + 1);
          
    
          userAccount = parentAccount;
        }
        return success;
      }
      
      

    
}
