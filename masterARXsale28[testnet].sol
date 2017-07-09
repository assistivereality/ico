pragma solidity ^0.4.11;
// [Assistive Reality ARX ERC20 token & crowdsale contract w/10% dev alloc]
// [v2.8 final released 10/07/2017 final masterARXsale28.sol]
// [Adapted from Ethereum standard crowdsale contract]
// [Contact assistivereality@gmail.com for any queries]
// [Math operations migrated to SafeMath equivalent]
// -------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/issues/20
// -------------------------------------------------
// Security reviews completed 10/07/2017
// - [X] integer math/overflow protection via SafeMath
// - [X] recursion / reentry safeguards
// - [X] ownership and inheritance of this modifier throughout
// - [X] sensitive function protection
// - [X] ERC20-compliant balance checking, integer math
// -------------------------------------------------
// 1.release tested: [v2.6 RC3 released 06/07/2017 final masterARsale26.sol, fully funded crowdsale]
// 2.release tested: [v2.8 RC3 released 10/07/2017 final masterARsale28.sol, fully funded crowdsale]
// 3.release tested: [v2.8 RC3 released 10/07/2017 final masterARsale28.sol, min funded crowdsale (ARX)]
// 4.release tested: [v2.8 RC3 released 10/07/2017 final masterARsale28.sol, failed crowdsale w/refunds (ARV)]
// -------------------------------------------------
// Functional reviews completed 10/07/2017
// [X][X][X][X]	(Crowdsale) test	 1:	Verify only owner can initiate crowdsale or setup parameters.
// [X][X][X][X]	(Crowdsale) test	 2:	Crowdsale is properly initialized with given parameters.
// [X][X][X][X]	(Crowdsale) test	 3:	Verify prevention of post-init modification crowdsale parameters.
// [X][X][X][X]	(Crowdsale) test	 4:	User cannot participate to the crowdsale too early via BuyTokens.
// [X][X][X][X]	(Crowdsale) test	 5:	User cannot participate to the crowdsale too early via sending eth.
// [X][X][X][X]	(Crowdsale) test	 6:	Check the checkGoalReached function interacts with isCrowdsaleCompleted variable as desired.
// [X][X][X][X]	(Crowdsale) test	 7:	Users sending eth to crowdsale address successfully buy token at the correct price (input in Eth).
// [X][X][X][X]	(Crowdsale) test	 8:	Users can buy tokens via BuyTokens function at the correct price (input in Eth).
// [X][X][X][X]	(Crowdsale) test	 9:	Users cannot purchase tokens via BuyTokens when crowdsale is halted.
// [X][X][X][X]	(Crowdsale) test	 10:	Users cannot purchase tokens via sending eth when crowdsale is halted.
// [X][X][X][X]	(Crowdsale) test	 11:	Watch token and Watch contract(crowdsale) via address and JSON functions as intended.
// [X][X][X][X]	(Crowdsale) test	 12:	Users can purchase tokens via both methods (sending Eth, or executing BuyTokens) when crowdsale is resumed.
// [X][X][X][X]	(Crowdsale) test	 13:	Users cannot exceed the maxFundingCap under any combination of conditions.
// [X][X][X][X]	(Crowdsale) test	 14:	Crowdsale flags as completed when checkGoalReached is executed under correct conditions.
// [X][X][X][X]	(Crowdsale) test	 15:	User cannot purchase tokens when crowdsale is completed via either method.
// [X][X][X][X]	(Crowdsale) test	 16:	+10% of total generated tokens are sent to foundation post-sale when founder runs AllocateFounderTokens.
// [X][X][X][X]	(Crowdsale) test	 17:	Founder can execute BeneficiaryWithdraw post-sale if min-funded or higher to transfer raised Eth to multi-sig wallet.
// [X][X][X][X]	(Crowdsale) test	 18:	User purchased, and foundation allocated tokens are generated, sent, and their purchase recorded correctly.
// [X][X][X][X]	(Crowdsale) test	 19:	Integer Overflow protection working.
// [X][X][X][X]	(Crowdsale) test	 20:	Verify refunds work, based on soft cap not reached & crowdsale deadline expired. User executes refund() &gets Eth.
// [X][X][X][X]	(Crowdsale) test	 21:	Test checkGoalReached successfully updates status if deadline has expired.
// [X][X][X][X]	(Crowdsale) test	 22:	Verify security and run conditions on checkGoalReached and refund functions.
// [X][X][X][X]	(Crowdsale) test	 23:	Only original owner can execute ownership protected functions (halt, unhalt).
// [X][X][X][X]	(Crowdsale) test	 24:	Verify founderTokensAvailable starts false & becomes true only when max funded or expired & above min funding cap.
// [X][X][X][X]	(Crowdsale) test	 25:	Verify BuyToken only sends to msg.sender even if overriden (required for refunds).
// [X][X][X][X]	(ERC-20) test		   26:	ERC-20 compatible transfer() is available and functional.
// [X][X][X][X]	(ERC-20) test		   27:	ERC-20 transfer fails if user exceeds his/her balance.
// [X][X][X][X]	(ERC-20) test		   28:	ERC-20 compatible transferFrom() is available and functional.
// [X][X][X][X]	(ERC-20) test		   29:	User can set allowance approval list for transfers.
// [X][X][X][X]	(ERC-20) test		   30:	Tokens can be transferred with ECR-20 allowance approval.
// [X][X][X][X]	(ERC-20) test		   31:	transferFrom fails if user exceeds his/her allowance or from balance.
// [X][X][X][X]	(ERC-20) test		   32:	User cannot transfer more than approved allowance.
// [X][X][X][X]                         [verified]

contract owned {
    address public owner;
    function owned() {
        owner = msg.sender;
    }
    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract SafeMath {
  function safeMul(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal returns (uint256) {
    assert(b > 0);
    uint256 c = a / b;
    assert(a == b * c + a % b);
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a + b;
    assert(c>=a && c>=b);
    return c;
  }

  function assert(bool assertion) internal {
    if (!assertion) throw;
  }
}

contract ERC20Interface is owned, SafeMath {
    function totalSupply() constant returns (uint256 totalSupply);
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
    event Buy(address indexed _sender, uint256 _eth, uint256 _ARX);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Burn(address _from, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Refund(address indexed _refunder, uint256 _value);
}

contract ARXCrowdsale is ERC20Interface {
    // deployment variables for dynamic supply token
    string public constant standard   =           "ARX";
    string public constant name       =           "ARX";
    string public constant symbol     =           "ARX";
    uint8  public constant decimals   =           18;
    uint256 _totalSupply              =           0;

    address public admin = owner;                 // admin address
    uint256 public fundingStartBlock;             // crowdsale start block#
    uint256 public fundingEndBlock;               // crowdsale end block#
    address public beneficiaryMultiSig;           // beneficiaryMultiSig (founder group) multi-sig wallet account
    uint256 public tokensPerEthPrice;             // priceVar e.g. 20,000,000 tokens per Eth
    uint256 public amountRaisedInWei;             // total amount raised in Wei e.g. 21 000 000 000 000 000 000 = 21Eth
    uint256 public fundingMaxInWei;               // Eth funding max in Wei e.g. 21 000 000 000 000 000 000 = 21Eth
    uint256 public fundingMinInWei;               // Eth funding min in Wei e.g. 11 000 000 000 000 000 000 = 11Eth
    uint256 public fundingMaxInEth;               // Eth funding max in Wei e.g. 21Eth
    uint256 public fundingMinInEth;               // Eth funding min in Wei e.g. 11Eth
    uint256 public foundationFundAllocInWei;      // (fundingMaxInWei/10) foundationFundMultisig tokens post-crowdsale that go to Assistive Reality foundation multi-sig for developer distributions
    address public foundationFundMultisig;        // foundationFundMultisig multi-sig wallet address - Assistive Reality foundation fund
    uint256 public remainingCapInWei;             // amount of cap remaining to raise in Wei e.g. 1 000 000 000 000 000 000 = 1Eth remaining to raise
    uint256 public remainingCapInEth;             // amount of cap remaining to raise in Eth e.g. 1
    bool    public isCrowdSaleComplete = false;   // boolean for crowdsale completed or not
    bool    public isCrowdSaleSetup = false;      // boolean for crowdsale setup
    bool    public halted = false;                // boolean for halted or not
    bool    public founderTokensAvailable = false;// variable to set false after generating founderTokens

    // balances and transfer allowance arrays
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    event Buy(address indexed _sender, uint256 _eth, uint256 _ARX);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Burn(address _from, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Refund(address indexed _refunder, uint256 _value);

    function ARXCrowdsale() onlyOwner {
      admin = msg.sender;
    }

    // total supply value for the token
    function totalSupply() constant returns (uint256 totalSupply) {
        totalSupply = _totalSupply;
    }

    // get the account balance
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    // returns approximate crowdsale max funding in Eth
    function fundingMaxInEth() constant returns (uint256 fundingMaxInEth) {
      fundingMaxInEth = safeDiv(fundingMaxInWei,1 ether);
    }

    // returns approximate crowdsale min funding in Eth
    function fundingMinInEth() constant returns (uint256 fundingMinInEth) {
      fundingMinInEth = safeDiv(fundingMinInWei,1 ether);
    }

    // returns approximate crowdsale progress (funds raised) in Eth
    function amountRaisedInEth() constant returns (uint256 amountRaisedInEth) {
      amountRaisedInEth = safeDiv(amountRaisedInWei,1 ether);
    }

    // returns approximate crowdsale remaining cap (hardcap) in Eth
    function remainingCapInEth() constant returns (uint256 remainingCapInEth) {
      remainingCapInEth = safeDiv(remainingCapInWei,1 ether);
    }

    // send tokens
    function transfer(address _to, uint256 _amount) returns (bool success) {
        if (_to == 0x0) throw;
        if (balances[msg.sender] >= _amount
            && _amount > 0
            && safeAdd(balances[_to],_amount) > balances[_to]) {
            uint256 senderBalance = balances[msg.sender];
            senderBalance = safeSub(senderBalance, _amount);
            balances[msg.sender] = senderBalance;
            balances[_to] = safeAdd(balances[_to], _amount);
            Transfer(msg.sender, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    // another contract attempts to get the coins
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount) returns (bool success) {
        if (_to == 0x0) throw;
        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0
            && safeAdd(balances[_to],_amount) > balances[_to]) {
            uint256 senderFBalance = 0;
            uint256 senderAllowBalance = 0;
            senderFBalance = safeSub(balances[_from], _amount);
            balances[_from] = senderFBalance;
            senderAllowBalance = safeSub((allowed[_from][msg.sender]),_amount);
            allowed[_from][msg.sender] = senderAllowBalance;
            balances[_to] = safeAdd(balances[_to], _amount);
            Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    // allow _spender to withdraw, multiple times, up to the _value amount.
    function approve(address _spender, uint256 _amount) returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    // return allowance for given owner spender pair
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    // setup the CrowdSale parameters
    function SetupCrowdsale(uint256 _fundingStartBlock, uint256 _fundingEndBlock) onlyOwner returns (bytes32 response) {
        if (msg.sender == admin && !(beneficiaryMultiSig > 0 && fundingMaxInWei > 0)) {
            beneficiaryMultiSig = 0xfF48cfed7A7c6b401b87dcC31C04BF1520C26B8C;
            foundationFundMultisig = 0x525A572aF2d683b1df45879C27d558Fa3E672C6C;
            fundingMaxInWei = 21000000000000000000; //21 000 000 000 000 000 000 = 21Eth (hard cap) - crowdsale no longer accepts Eth after this value
            fundingMinInWei = 11000000000000000000; //11 000 000 000 000 000 000 = 11Eth (soft cap) - crowdsale is considered success after this value
            fundingMaxInEth = safeDiv(fundingMaxInWei,1 ether); //approximate to 1Eth due to resolution, provided for ease/viewing only
            fundingMinInEth = safeDiv(fundingMinInWei,1 ether); //approximate to 1Eth due to resolution, provided for ease/viewing only
            remainingCapInWei = fundingMaxInWei;
            remainingCapInEth = safeDiv(remainingCapInWei,1 ether); //approximate to 1Eth due to resolution, provided for ease/viewing only
            fundingStartBlock = _fundingStartBlock;
            fundingEndBlock = _fundingEndBlock;
            tokensPerEthPrice = 20000000; // tokens per Eth
            isCrowdSaleSetup = true;
            return "campaign is set";
        } else if (msg.sender != admin) {
            return "not authorized";
        } else  {
            return "campaign cannot be changed";
        }
    }

    // default payable function when sending ether to this contract
    function () payable {
      if (msg.data.length != 0) return;
      if (!isCrowdSaleSetup) throw;
      BuyTokens(msg.sender);
    }

    function BuyTokens(address recipient) payable {
      // for a number of reasons (gas issue, load reduction, best practices) we are using beneficiaryMultiSigWithdraw instead of: (if (!beneficiaryMultiSig.send(msg.value)) throw) at end of block #1 below;
      // 0. vars
      uint256 amount = msg.value;
      uint256 TotalAfterContribution = safeAdd(amountRaisedInWei,amount);
      uint256 rewardTransferAmount = 0;
      recipient = msg.sender; // added to simplify refunding, to prevent people buying on other's behalf, or even providing wrong address to receive - this overrides any manually entered recipient address to send tokens to msg.sender (ether sender)

      // 1. conditions (length, crowdsale setup, zero check, exceed funding contrib check, contract valid check, within funding block range check, balance overflow check etc)
      if (halted) throw;
      if (!isCrowdSaleSetup) throw;
      if (amount == 0) throw;
      if (TotalAfterContribution > fundingMaxInWei) throw;
      if (!(block.number >= fundingStartBlock && block.number <= fundingEndBlock)) throw;
      if (isCrowdSaleComplete) throw;

      // 2. effects
      amountRaisedInWei = safeAdd(amountRaisedInWei,amount);
      remainingCapInWei = safeSub(fundingMaxInWei,amountRaisedInWei);
      rewardTransferAmount = safeMul(amount,tokensPerEthPrice);

      if (amountRaisedInWei >= fundingMaxInWei) {
        isCrowdSaleComplete = true;
      }

      if (amountRaisedInWei >= fundingMinInWei) {
        founderTokensAvailable = true;
      }

      // 3. interaction (throw if fail to generate for any reason)
      balances[recipient] = safeAdd(balances[recipient], rewardTransferAmount);
      _totalSupply = safeAdd(_totalSupply, rewardTransferAmount);
      Transfer(this, recipient, rewardTransferAmount);
      Buy(recipient, amount, rewardTransferAmount);
    }

    function AllocateFounderTokens() onlyOwner {
      if ((isCrowdSaleComplete) && (amountRaisedInWei >= fundingMinInWei) && (founderTokensAvailable)) {
        // calculate additional 10% tokens to allocate for foundation developer distributions
          foundationFundAllocInWei = safeDiv(amountRaisedInWei,10);
          foundationFundAllocInWei = safeMul(foundationFundAllocInWei,tokensPerEthPrice);
          // generate and send foundation developer token distributions
          balances[foundationFundMultisig] = safeAdd(balances[foundationFundMultisig], foundationFundAllocInWei);
          _totalSupply = safeAdd(_totalSupply, foundationFundAllocInWei);
          Transfer(this, foundationFundMultisig, foundationFundAllocInWei);
          Buy(foundationFundMultisig, 0, foundationFundAllocInWei);
          founderTokensAvailable = false;
      }
      //do nothing if all conditions don't match
    }

    function beneficiaryMultiSigWithdraw(uint256 _amount) onlyOwner {
      // .transfer includes the throw and is better practice than if !(x.send) throw;
      if (isCrowdSaleComplete) {
        // if crowdsale period completed allow multi-sig withdraw
        beneficiaryMultiSig.transfer(_amount);
        //Transfer(msg.sender, beneficiaryMultiSig, _amount);
      } else if ((halted) && (amountRaisedInWei >= fundingMinInWei)) {
        // if crowdsale emergency halted and minimum funding met
        beneficiaryMultiSig.transfer(_amount);
        //Transfer(msg.sender, beneficiaryMultiSig, _amount);
      }
      //do nothing if no conditions match
    }

    // check status and update crowdfund to complete if deadline expired
    function checkGoalReached() onlyOwner returns (bytes32 response) {
        if (amountRaisedInWei >= fundingMaxInWei) {
            isCrowdSaleComplete = true;
            founderTokensAvailable = true;
            return "Crowdsale funded to hardcap";
        } else if (block.number >= fundingEndBlock) {
            isCrowdSaleComplete = true;
            if (amountRaisedInWei >= fundingMinInWei) {
              founderTokensAvailable = true;
            }
            return "Crowdsale deadline passed";
        }
        return "Goal not reached yet";
    }

    function refund() {
      // halt protection
      if (halted) throw;
      // refunds available if soft cap not reached and deadline expires
      if ((amountRaisedInWei < fundingMinInWei) && (block.number >= fundingEndBlock)) {
        uint256 ARXbalance = balances[msg.sender];
        if (ARXbalance == 0) throw;
        balances[msg.sender] = 0;
        _totalSupply = safeSub(_totalSupply, ARXbalance);
        Burn(msg.sender, ARXbalance);
        uint256 ethValue = safeDiv(ARXbalance, tokensPerEthPrice);
        msg.sender.transfer(ethValue);
        amountRaisedInWei = safeSub(amountRaisedInWei, ethValue);
        Refund(msg.sender, ethValue);
      }
    }

    function halt() onlyOwner {
        halted = true;
    }

    function unhalt() onlyOwner {
        halted = false;
    }
}
