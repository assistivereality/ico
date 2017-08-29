pragma solidity ^0.4.11;
// -------------------------------------------------
// [Assistive Reality ARX ERC20 token & crowdsale contract w/10% dev alloc]
// [v2.9 final released 29/08/2017 final masterARXsale29.sol]
// [Adapted from Ethereum standard crowdsale contract]
// [Contact staff@aronline.io for any queries]
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
// 1.release tested: [v2.8 RC3 released 10/07/2017 final masterARsale28.sol, fully funded crowdsale]
// 2.release tested: [v2.8 RC3 released 10/07/2017 final masterARsale28.sol, min funded crowdsale (ARX)]
// 3.release tested: [v2.8 RC3 released 10/07/2017 final masterARsale28.sol, failed crowdsale w/refunds (ARV)]
// 4.release tested: [v2.9 released 29/08/2017 final masterARsale29.sol, fully funded crowdsale (ARX)]
// -------------------------------------------------
// Functional reviews completed 29/08/2017
// full list of functional tests and results here (we encourage you to review):
// https://github.com/assistivereality/ico/blob/master/2.9-crowdsaletests%5Btestnet%5D(masterARXsale2.9final).txt
// -------------------------------------------------

contract owned {
    address public owner;
    function owned() {
        owner = msg.sender;
    }
    modifier onlyOwner {
        if (msg.sender != owner) revert();
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
    if (!assertion) revert();
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
    string public constant standard   =             "ARX";
    string public constant name       =             "ARX";
    string public constant symbol     =             "ARX";
    uint8  public constant decimals   =             18;
    uint256 _totalSupply              =             0;

    address public admin = owner;                   // admin address
    uint256 public fundingStartBlock;               // crowdsale start block#
    uint256 public fundingEndBlock;                 // crowdsale end block#
    address public beneficiaryMultiSig;             // beneficiaryMultiSig (founder group) multi-sig wallet account
    uint256 public tokensPerEthPrice;               // priceVar e.g. 20,000,000 tokens per Eth
    uint256 public amountRaisedInWei;               // total amount raised in Wei e.g. 21 000 000 000 000 000 000 = 21 Eth
    uint256 public fundingMaxInWei;                 // funding max in Wei e.g. 21 000 000 000 000 000 000 = 21 Eth
    uint256 public fundingMinInWei;                 // funding min in Wei e.g. 11 000 000 000 000 000 000 = 11 Eth
    uint256 public fundingMaxInEth;                 // funding max in Eth (approx) e.g. 21 Eth
    uint256 public fundingMinInEth;                 // funding min in Eth (approx) e.g. 11 Eth
    uint256 public foundationFundAllocInWei;        // (fundingMaxInWei/10) foundationFundMultisig tokens post-crowdsale that go to Assistive Reality foundation
    address public foundationFundMultisig;          // foundationFundMultisig multi-sig wallet address - Assistive Reality foundation fund
    uint256 public remainingCapInWei;               // amount of cap remaining to raise in Wei e.g. 1 200 000 000 000 000 000 = 1.2 Eth remaining
    uint256 public remainingCapInEth;               // amount of cap remaining to raise in Eth (approx) e.g. 1
    bool    public isCrowdSaleComplete = false;     // boolean for crowdsale completed or not
    bool    public isCrowdSaleSetup = false;        // boolean for crowdsale setup
    bool    public halted = false;                  // boolean for halted or not
    bool    public founderTokensAvailable = false;  // variable to set false after generating founderTokens

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
        if (_to == 0x0) revert();
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
        if (_to == 0x0) revert();
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
            // testnet values only
            beneficiaryMultiSig = 0x6e537D243264b286E46C623C7c5CB65D12be81eA;
            foundationFundMultisig = 0xA0170362e7a68bEAA754E0C35f3af0C6384236bD;

            // funding targets with 18 decimals
            fundingMaxInWei = 160000000000000000000;      //160 000 000 000 000 000 000 = 160 Eth (hard cap) - crowdsale no longer accepts Eth after this value
            fundingMinInWei = 16000000000000000000;       // 16 000 000 000 000 000 000 =  16 Eth (soft cap) - crowdsale is considered success after this value

            /* mainnet live crowdsale deployment target values
            fundingMaxInWei = 160526000000000000000000; //160 500 000 000 000 000 000 000 = 160,050 Eth (hard cap) - crowdsale no longer accepts Eth after this value
            fundingMinInWei = 16050000000000000000000;   //16 050 000 000 000 000 000 000 =  16,050 Eth (soft cap) - crowdsale is considered success after this value
            */

            // at testnet value 2,000 tokens per Eth caps testnet crowdsale of 160Eth at approximately 320,000 tokens generated + founders grant (32,000 max) = max 352,000 ARX tokens
            tokensPerEthPrice = 2000; // 2,000 or 2000 tokens per Eth

            fundingMaxInEth = safeDiv(fundingMaxInWei,1 ether); //approximate to 1 Eth due to resolution, provided for ease/viewing only
            fundingMinInEth = safeDiv(fundingMinInWei,1 ether); //approximate to 1 Eth due to resolution, provided for ease/viewing only

            remainingCapInWei = fundingMaxInWei;
            remainingCapInEth = safeDiv(remainingCapInWei,1 ether); //approximate to 1 Eth due to resolution, provided for ease/viewing only
            fundingStartBlock = _fundingStartBlock;
            fundingEndBlock = _fundingEndBlock;

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
      if (!isCrowdSaleSetup) revert();
      BuyTokens(msg.sender);
    }

    function BuyTokens(address recipient) payable {
      // for a number of reasons (gas issue, load reduction, best practices) we are using beneficiaryMultiSigWithdraw instead of: (if (!beneficiaryMultiSig.send(msg.value)) revert()) at end of block #1 below;
      // 0. vars
      uint256 amount = msg.value;
      uint256 TotalAfterContribution = safeAdd(amountRaisedInWei,amount);
      uint256 rewardTransferAmount = 0;
      recipient = msg.sender; // added to simplify refunding, to prevent people buying on other's behalf, or even providing wrong address to receive - this overrides any manually entered recipient address to send tokens to msg.sender (ether sender)

      // 1. conditions (length, crowdsale setup, zero check, exceed funding contrib check, contract valid check, within funding block range check, balance overflow check etc)
      if (halted) revert();
      if (!isCrowdSaleSetup) revert();
      if (amount == 0) revert();
      if (TotalAfterContribution > fundingMaxInWei) revert();
      if (!(block.number >= fundingStartBlock && block.number <= fundingEndBlock)) revert();
      if (isCrowdSaleComplete) revert();

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

      // 3. interaction
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
      // .transfer includes the revert() and is better practice than if !(x.send) revert();
      if (isCrowdSaleComplete) {
        // if crowdsale period completed allow multi-sig withdraw
        beneficiaryMultiSig.transfer(_amount);
      } else if ((halted) && (amountRaisedInWei >= fundingMinInWei)) {
        // if crowdsale emergency halted and minimum funding met
        beneficiaryMultiSig.transfer(_amount);
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
      if (halted) revert();
      // refunds available if soft cap not reached and deadline expires
      if ((amountRaisedInWei < fundingMinInWei) && (block.number >= fundingEndBlock)) {
        uint256 ARXbalance = balances[msg.sender];
        if (ARXbalance == 0) revert();
        balances[msg.sender] = 0;
        _totalSupply = safeSub(_totalSupply, ARXbalance);
        uint256 ethValue = safeDiv(ARXbalance, tokensPerEthPrice);
        amountRaisedInWei = safeSub(amountRaisedInWei, ethValue);
        msg.sender.transfer(ethValue);
        Burn(msg.sender, ARXbalance);
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
