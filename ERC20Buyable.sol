pragma solidity ^0.6.0;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract Buyable is IERC20{
    using SafeMath for uint256;
    using Address for address;
    
    mapping(address => uint256) private _balances;
    
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // delegated addresses
    
    mapping(address => bool) approved_addresses;
    
    
    // number of purchase history
    mapping (address => uint256) purchaseHistoryIndex;
    
    // refundableAmount 
    
    mapping (address => uint256) refundableAmount;
    
    // struct 
    
    struct purchasedTransaction{
        uint256 amount;
        uint256 amountRefunded;
        uint256 expiry;
    }
    
    mapping (address => mapping (uint256 => purchasedTransaction)) transactionDetails;
    
    uint256 public _cappedLimit = 20000000000;
    uint256 private _totalSupply;
    
    address public owner;
    
    string public name; 
    string public symbol;
    uint8 public decimals;
    uint256 public rateOfToken;
    // timestampLock
    
    // uint256 public time = 86400 * 30;
    
    // tokenPaused flag
    bool public _tokenPaused = false;
    // isActive modifier
    modifier isActive() {
        require(_tokenPaused == false, "Permission denied token is paused");
        _;
    }
    
    
    // isOwner modifier
    
    modifier isOwner(){
        require(msg.sender == owner,"you don't have rights to do this action");
        _;
    }
    // is tokenOwner modifier
    modifier isTokenOwner(){
        require(_balances[msg.sender] > 0, "sorry you don't posses tokens");
        _;
    }
    
    // spender modifier
    modifier isSpender(address _tokenOwner, address _spender){
        require(_allowances[_tokenOwner][_spender] > 0, "you don't have allowance");
        _;
    }
    // isOwnerOrDelegated modifier
    modifier isOwnerOrDelegated(){
        require(msg.sender == owner || approved_addresses[msg.sender],"you don't have rights to take this action");
        _;
    }
    
    constructor(uint256 _priceOfToken) public{
        require(_priceOfToken > 0 ," please mentioned price of token against one Ehter");
        name = "PIAIC-BCC BATCH-1 TOKEN";
        symbol = "BCC1";
        decimals = 18;
        owner = msg.sender;
        rateOfToken = _priceOfToken;
        _totalSupply = 1000000 * 10 ** uint256(decimals);
        _balances[owner] = _totalSupply;
        emit Transfer(address(this), owner, _totalSupply);
    }
    
    function totalSupply() public override view returns(uint256){
        return _totalSupply;
    }
    
    function balanceOf(address account) public override view returns(uint256){
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override isTokenOwner isActive returns(bool success) {
        address sender = msg.sender;
        require(sender != address(0), 'sender from zero address');
        require(recipient != address(0), 'sender from zero address');
        require(_balances[sender] >= amount, "requested amount is exceeded than actual balance");
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        
        emit Transfer(sender, recipient, amount);
        return true;
    }
    
    function allowance(address tokenOwner, address spender) public isTokenOwner override view returns(uint256){
        return _allowances[tokenOwner][spender];
    } 
    
    function approve(address spender, uint256 amount) public isTokenOwner override returns(bool){
        address tokenOwner = msg.sender;
        require(tokenOwner != address(0),"transaction can't be initiated from zero based address");
        require(spender != address(0),"spender can't be a zero based address");
        
        _allowances[tokenOwner][spender] = _allowances[tokenOwner][spender].add(amount);
        emit Approval(tokenOwner, spender, amount);
        
        return true;
    }
    
    function transferFrom(address tokenOwner, address recipient, uint256 amount) public isSpender(tokenOwner,msg.sender) isActive override returns (bool){
        address spender = msg.sender;
        uint256 _allowance = _allowances[tokenOwner][spender];
        require(_allowance > amount,"BCC1- Transfer amount exceed allowance");
        //deducting allowance
        _allowance = _allowance.sub(amount);
        
        // subtraction of amount from the owner
        _balances[tokenOwner] = _balances[tokenOwner].sub(amount);
        
        // adding the amount to the recipient;
        _balances[recipient] = _balances[recipient].add(amount);
        
        emit Transfer(tokenOwner, recipient, amount);
        
        // allowance adjustment
        _allowances[tokenOwner][spender] = _allowance;
        emit Approval(tokenOwner, spender, amount);
        
        return true;
        
        
    }
    
    // mintable function
    
    function mintable(uint256 amount) public isOwner returns(bool){
        require(amount > 0 , "amount must be greater than 0");
        require(_totalSupply.add(amount) <= _cappedLimit, "you can't mint tokens more than capped limit");
        _totalSupply = _totalSupply.add(amount);
        _balances[owner] = _balances[owner].add(amount);
        return true;
    }
    
    
    
    // Ownable changing of the owner function 
    
    function changeOwner(address newOwner) public isOwner returns(bool){
        require(newOwner != address(0),"should be valid address");
        if(newOwner == owner){
            revert('you are already a owner');
        }
        transfer(newOwner, _balances[owner]);
        owner = newOwner;
    }
    
    // function rateOfToken
    
    function adjustPrice(uint256 amount) public isOwnerOrDelegated returns(bool){
        require(amount > 0,"amount must be greater than zero");
        rateOfToken = amount;
    }
    
    // fallback function 
    
    fallback() payable external{
        // uint256 amount = msg.value;
        purchaseToken();
    }
    
    function purchaseToken() public payable returns (bool){
        
        require(!Address.isContract(msg.sender),"must be EOA");
        require(msg.value > 0,"amount must be greater than zero");
        uint256 amount =  msg.value * rateOfToken;
        
        purchaseHistoryIndex[msg.sender] ++;
        purchasedTransaction storage s1 = transactionDetails[msg.sender][purchaseHistoryIndex[msg.sender]];
        s1.amount = amount;
        s1.expiry = now.add(3 minutes);
        
        
        _balances[msg.sender] += amount;
        _balances[owner] -= amount;
        
        return true;
        
    }
    
    function collectFunds() public isOwner returns(bool) {
        payable(owner).transfer(address(this).balance);
        return true;
    }
    
    // approved specific users to change the price of the token;
    
    function approval(address _address) public isOwner returns(bool){
        approved_addresses[_address] = true;
        return true;
    } 
    
    // remove approved_addresses 
    
    function removal(address _address) public isOwner returns(bool){
        approved_addresses[_address] = false;
        return true;
    }
    
    function numberOfPurchaseTransaction() public isTokenOwner view returns(uint256){
        return purchaseHistoryIndex[msg.sender];
    }
    
    function yourRefundableAmount(address _address) public isTokenOwner returns(uint256){
        refundableAmount[_address] = 0;
        for(uint256 i = purchaseHistoryIndex[_address]; i > 0 ; i--){
            purchasedTransaction storage s1 = transactionDetails[_address][i];
            if(s1.expiry >= now){
                refundableAmount[_address] += s1.amount.sub(s1.amountRefunded);
            }
            else{
                break;
            }
        }
        return refundableAmount[_address];
    }
    
    // to get your ethers back by exchange tokens with ethers and you must fill the amount of tokens equals to 1 wei
    // if 1 ether = 200 tokens (200,000,000,000,000,000,000)
    // 0.005 ether = 1 token (1000,000,000,000,000,000)
    // e.g. 1 wei = 200  ( part of 1 token like cents in rupees) then amount must be equal or greater than 100 and should be multiple of 100
    // then less 200 can't be exchange against wei it must be multiple of 1 wei's amount
    // ethers will be return in the form of multiple of token's amount equals to one wei
    function getYourEtherBack(uint _amount) public isTokenOwner returns(bool){
        uint adjuestedAmountOfToken = _amount.sub(_amount.mod(rateOfToken));
        require(adjuestedAmountOfToken >= rateOfToken,"amount of token must be greater or equals to 1 wei's");
        require(yourRefundableAmount(msg.sender) >= adjuestedAmountOfToken , "date is gone you can't exchange tokens now!");
        uint amount = adjuestedAmountOfToken.div(rateOfToken);
        require(address(this).balance >= amount,"owner doesn't have enough balance");
        transfer(owner, adjuestedAmountOfToken);
        msg.sender.transfer(amount);
    }
}
