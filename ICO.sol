//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.0;

//EIP-20: ERC-20 Token Standard
//https://eips.ethereum.org/EIPS/eip-20

interface ERC20Interface{
    //First 3 are the mandatory functions to be overridden in derived class
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns(uint balance);
    function transfer(address to, uint tokens) external returns(bool success);

    function allowance(address tokenOwner, address spender) external view returns(uint remaining);
    function approve(address spender, uint tokens) external returns(bool success);
    function transferFrom(address from, address to, uint tokens) external returns(bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Cryptos is ERC20Interface{
    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint public decimals = 0; //18 generally

    uint public override totalSupply;

    address public founder;
    mapping(address => uint) public balances;

    mapping(address => mapping(address => uint)) allowed;
    
    constructor(){
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenOwner) public view override returns(uint balance){
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public virtual override returns(bool success){
        require(balances[msg.sender] >= tokens);

        balances[to] += tokens;
        balances[msg.sender] -= tokens;

        emit Transfer(msg.sender, to, tokens);
        
        return true;
    }

    function allowance(address tokenOwner, address spender) view public override returns(uint){
        return allowed[tokenOwner][spender];
    }

    function approve(address spender, uint tokens) public override returns(bool success){
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public virtual override returns(bool success){
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);
        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;
        emit Transfer(from, to, tokens);
        return true;
    }
}


contract CryptosICO is Cryptos{
    address public admin;
    address payable public deposit;
    uint tokenPrice = 0.001 ether; //1 ETH = 1000 CRPT
    uint public hardCap = 300 ether;
    uint raisedAmount;
    uint public saleStart = block.timestamp;
    //If you want some other time like after 1 hour, then add the number of seconds - 
    // uint public saleStart = block.timestamp + 3600;
    uint saleEnd = block.timestamp + 604800; //ICO ends in a week
    uint public tokenTradeStart = saleEnd + 604800; //Transferable in a week after ICO ends because we do not want the token's market price to get dumped
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;
    enum State {beforeStart, running, afterEnd, halted}
    State public ICOState;

    constructor(address payable _deposit){
        deposit = _deposit;
        admin = msg.sender;
        ICOState = State.beforeStart;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin);
        _;
    }

    function halt() public onlyAdmin{
        ICOState = State.halted;        
    }

    function resume() public onlyAdmin{
        ICOState = State.running;
    }

    function changeDepositAddress(address payable newDeposit) public onlyAdmin{
        deposit = newDeposit;
    }

    function getCurrentState() public view returns(State){
        if(ICOState == State.halted){
            return State.halted;
        }
        else if(block.timestamp < saleStart){
            return State.beforeStart;
        }
        else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }
        else{
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint tokens);

    function invest() payable public returns(bool){
        ICOState = getCurrentState();
        require(ICOState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;

        require(raisedAmount <= hardCap);

        uint tokens = msg.value/tokenPrice;

        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value);

        emit Invest(msg.sender, msg.value, tokens);

        return true;
    }

    receive() external payable{
        invest();
    }

    function transfer(address to, uint tokens) public override returns(bool success){
        require(block.timestamp > tokenTradeStart);
        super.transfer(to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns(bool success){
        require(block.timestamp > tokenTradeStart);
        Cryptos.transferFrom(from, to, tokens);
        return true;
    }

    function burn() public returns(bool){
        ICOState = getCurrentState();
        require(ICOState == State.afterEnd);
        balances[founder] = 0;
        return true;
    }
}
