pragma solidity ^0.4.18;

// -------------------------------------------------
// Assistive Reality.io ICO token sale contract
// Final revision 22b
// Refunds integrated, full test suite passed
// -------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/issues/20
// -------------------------------------------------
// Recent changes:
// - Updates to comply with latest Solidity versioning (0.4.18):
// -   Classification of internal/private vs public functions
// -   Specification of pure functions such as SafeMath integrated functions
// -   Conversion of all constant to view or pure dependant on state changed
// -   Full regression test of code updates
// -   Revision of block number timing for new Ethereum block times
// - Removed duplicate Buy/Transfer event call in buyARXtokens
// - Burn event now records number of ARX tokens burned vs Refund event Eth
// - Transfer event now fired when beneficiaryWallet withdraws
// -------------------------------------------------
// Price configuration:
// First Day Bonus    +50% = 1,500 ARX  = 1 ETH       [blocks: start -> s+5959]
// First Week Bonus   +40% = 1,400 ARX  = 1 ETH       [blocks: s+5960  -> s+41710]
// Second Week Bonus  +30% = 1,300 ARX  = 1 ETH       [blocks: s+41711 -> s+83421]
// Third Week Bonus   +25% = 1,250 ARX  = 1 ETH       [blocks: s+83422 -> s+125131]
// Final Week Bonus   +15% = 1,150 ARX  = 1 ETH       [blocks: s+125132 -> endblock]
// -------------------------------------------------

contract owned {
    address public owner;

    function owned() internal {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

contract safeMath {
  function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    safeAssert(a == 0 || c / a == b);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    safeAssert(b > 0);
    uint256 c = a / b;
    safeAssert(a == b * c + a % b);
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    safeAssert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    safeAssert(c>=a && c>=b);
    return c;
  }

  function safeAssert(bool assertion) internal pure {
    if (!assertion) revert();
  }
}

contract StandardToken is owned, safeMath {
  function balanceOf(address who) view public returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ARXCrowdsale is owned, safeMath {
  // owner/admin & token reward
  address        public admin                     = owner;    // admin address
  StandardToken  public tokenReward;                          // address of the token used as reward

  // deployment variables for static supply sale
  uint256 public initialSupply;
  uint256 public tokensRemaining;

  // multi-sig addresses and price variable
  address public beneficiaryWallet;                           // beneficiaryMultiSig (founder group) or wallet account, live is 0x00F959866E977698D14a36eB332686304a4d6AbA
  uint256 public tokensPerEthPrice;                           // set initial value floating priceVar 1,500 tokens per Eth

  // uint256 values for min,max,caps,tracking
  uint256 public amountRaisedInWei;                           //
  uint256 public fundingMinCapInWei;                          //

  // loop control, ICO startup and limiters
  string  public CurrentStatus                   = "";        // current crowdsale status
  uint256 public fundingStartBlock;                           // crowdsale start block#
  uint256 public fundingEndBlock;                             // crowdsale end block#
  bool    public isCrowdSaleClosed               = false;     // crowdsale completion boolean
  bool    public areFundsReleasedToBeneficiary   = false;     // boolean for founder to receive Eth or not
  bool    public isCrowdSaleSetup                = false;     // boolean for crowdsale setup

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Buy(address indexed _sender, uint256 _eth, uint256 _ARX);
  event Refund(address indexed _refunder, uint256 _value);
  event Burn(address _from, uint256 _value);
  mapping(address => uint256) balancesArray;
  mapping(address => uint256) usersARXfundValue;

  // default function, map admin
  function ARXCrowdsale() public onlyOwner {
    admin = msg.sender;
    CurrentStatus = "Crowdsale deployed to chain";
  }

  // total number of tokens initially
  function initialARXSupply() public view returns (uint256 tokenTotalSupply) {
      return safeDiv(initialSupply,100);
  }

  // remaining number of tokens
  function remainingSupply() public view returns (uint256 tokensLeft) {
      return tokensRemaining;
  }

  // setup the CrowdSale parameters
  function SetupCrowdsale(uint256 _fundingStartBlock, uint256 _fundingEndBlock) public onlyOwner returns (bytes32 response) {
      if ((msg.sender == admin)
      && (!(isCrowdSaleSetup))
      && (!(beneficiaryWallet > 0))){
          // init addresses
          tokenReward                             = StandardToken(0x2498E6d0D86a2b7777d6e0b0341DE50b49A115c4);  //mainnet is 0x7D5Edcd23dAa3fB94317D32aE253eE1Af08Ba14d //testnet = 0x75508c2B1e46ea29B7cCf0308d4Cb6f6af6211e0
          beneficiaryWallet                       = 0x304Ce6aa8ABcf0c92A50Bc340554f5283D3DecaD;   // mainnet is 0x00F959866E977698D14a36eB332686304a4d6AbA //testnet = 0xDe6BE2434E8eD8F74C8392A9eB6B6F7D63DDd3D7
          tokensPerEthPrice                       = 1500;                                         // set day1 initial value floating priceVar 1,500 tokens per Eth

          // funding targets
          fundingMinCapInWei                      = 6000000000000000000;                          //300000000000000000000 =  300 Eth (min cap) - crowdsale is considered success after this value  //testnet 6000000000000000000 = 6Eth

          // update values
          amountRaisedInWei                       = 0;
          initialSupply                           = 1100000;                                      //   7,500,000 + 2 decimals = 750000000 //testnet 1100000 =11,000
          tokensRemaining                         = safeDiv(initialSupply,100);
          fundingStartBlock                       = _fundingStartBlock;
          fundingEndBlock                         = _fundingEndBlock;

          // configure crowdsale
          isCrowdSaleSetup                        = true;
          isCrowdSaleClosed                       = false;
          CurrentStatus                           = "Crowdsale is setup";

          return "Crowdsale is setup";
      } else if (msg.sender != admin) {
          return "not authorized";
      } else  {
          return "campaign cannot be changed";
      }
    }

    function setPrice() internal {
      // Price configuration:
      // First Day Bonus    +50% = 1,500 ARX  = 1 ETH       [blocks: start -> s+5959]
      // First Week Bonus   +40% = 1,400 ARX  = 1 ETH       [blocks: s+5960  -> s+41710]
      // Second Week Bonus  +30% = 1,300 ARX  = 1 ETH       [blocks: s+41711 -> s+83421]
      // Third Week Bonus   +25% = 1,250 ARX  = 1 ETH       [blocks: s+83422 -> s+125131]
      // Final Week Bonus   +15% = 1,150 ARX  = 1 ETH       [blocks: s+125132 -> endblock]
      if (block.number >= fundingStartBlock && block.number <= fundingStartBlock+5959) { // First Day Bonus    +50% = 1,500 ARX  = 1 ETH  [blocks: start -> s+24]
        tokensPerEthPrice=1500;
      } else if (block.number >= fundingStartBlock+5960 && block.number <= fundingStartBlock+41710) { // First Week Bonus   +40% = 1,400 ARX  = 1 ETH  [blocks: s+25 -> s+45]
        tokensPerEthPrice=1400;
      } else if (block.number >= fundingStartBlock+41711 && block.number <= fundingStartBlock+83421) { // Second Week Bonus  +30% = 1,300 ARX  = 1 ETH  [blocks: s+46 -> s+65]
        tokensPerEthPrice=1300;
      } else if (block.number >= fundingStartBlock+83422 && block.number <= fundingStartBlock+125131) { // Third Week Bonus   +25% = 1,250 ARX  = 1 ETH  [blocks: s+66 -> s+85]
        tokensPerEthPrice=1250;
      } else if (block.number >= fundingStartBlock+125132 && block.number <= fundingEndBlock) { // Final Week Bonus   +15% = 1,150 ARX  = 1 ETH  [blocks: s+86 -> endBlock]
        tokensPerEthPrice=1150;
      }
    }

    // default payable function when sending ether to this contract
    function () public payable {
      require(msg.data.length == 0);
      buyARXtokens();
    }

    function buyARXtokens() public payable {
      // 0. conditions (length, crowdsale setup, zero check, exceed funding contrib check, contract valid check, within funding block range check, balance overflow check etc)
      require(!(msg.value == 0)
      && (isCrowdSaleSetup)
      && (block.number >= fundingStartBlock)
      && (block.number <= fundingEndBlock)
      && (tokensRemaining > 0));

      // 1. vars
      uint256 rewardTransferAmount    = 0;

      // 2. effects
      setPrice();
      amountRaisedInWei               = safeAdd(amountRaisedInWei,msg.value);
      rewardTransferAmount            = safeDiv(safeMul(msg.value,tokensPerEthPrice),10000000000000000);

      // 3. interaction
      tokensRemaining                 = safeSub(tokensRemaining, safeDiv(rewardTransferAmount,100));  // will cause throw if attempt to purchase over the token limit in one tx or at all once limit reached
      tokenReward.transfer(msg.sender, rewardTransferAmount);

      // 4. events
      usersARXfundValue[msg.sender]           = safeAdd(usersARXfundValue[msg.sender], msg.value);
      Buy(msg.sender, msg.value, rewardTransferAmount);
    }

    function beneficiaryMultiSigWithdraw(uint256 _amount) public onlyOwner {
      require(areFundsReleasedToBeneficiary && (amountRaisedInWei >= fundingMinCapInWei));
      beneficiaryWallet.transfer(_amount);
      Transfer(this, beneficiaryWallet, _amount);
    }

    function checkGoalReached() public onlyOwner returns (bytes32 response) { // return crowdfund status to owner for each result case, update public var
      // update state & status variables
      require (isCrowdSaleSetup);
      if ((amountRaisedInWei < fundingMinCapInWei) && (block.number <= fundingEndBlock && block.number >= fundingStartBlock)) { // ICO in progress, under softcap
        areFundsReleasedToBeneficiary = false;
        isCrowdSaleClosed = false;
        CurrentStatus = "In progress (Eth < Softcap)";
        return "In progress (Eth < Softcap)";
      } else if ((amountRaisedInWei < fundingMinCapInWei) && (block.number < fundingStartBlock)) { // ICO has not started
        areFundsReleasedToBeneficiary = false;
        isCrowdSaleClosed = false;
        CurrentStatus = "Crowdsale is setup";
        return "Crowdsale is setup";
      } else if ((amountRaisedInWei < fundingMinCapInWei) && (block.number > fundingEndBlock)) { // ICO ended, under softcap
        areFundsReleasedToBeneficiary = false;
        isCrowdSaleClosed = true;
        CurrentStatus = "Unsuccessful (Eth < Softcap)";
        return "Unsuccessful (Eth < Softcap)";
      } else if ((amountRaisedInWei >= fundingMinCapInWei) && (tokensRemaining == 0)) { // ICO ended, all tokens bought!
          areFundsReleasedToBeneficiary = true;
          isCrowdSaleClosed = true;
          CurrentStatus = "Successful (ARX >= Hardcap)!";
          return "Successful (ARX >= Hardcap)!";
      } else if ((amountRaisedInWei >= fundingMinCapInWei) && (block.number > fundingEndBlock) && (tokensRemaining > 0)) { // ICO ended, over softcap!
          areFundsReleasedToBeneficiary = true;
          isCrowdSaleClosed = true;
          CurrentStatus = "Successful (Eth >= Softcap)!";
          return "Successful (Eth >= Softcap)!";
      } else if ((amountRaisedInWei >= fundingMinCapInWei) && (tokensRemaining > 0) && (block.number <= fundingEndBlock)) { // ICO in progress, over softcap!
        areFundsReleasedToBeneficiary = true;
        isCrowdSaleClosed = false;
        CurrentStatus = "In progress (Eth >= Softcap)!";
        return "In progress (Eth >= Softcap)!";
      }
    }

    function refund() public { // any contributor can call this to have their Eth returned. user's purchased ARX tokens are burned prior refund of Eth.
      //require minCap not reached
      require ((amountRaisedInWei < fundingMinCapInWei)
      && (isCrowdSaleClosed)
      && (block.number > fundingEndBlock)
      && (usersARXfundValue[msg.sender] > 0));

      //burn user's token ARX token balance, refund Eth sent
      uint256 ethRefund = usersARXfundValue[msg.sender];
      balancesArray[msg.sender] = 0;
      usersARXfundValue[msg.sender] = 0;

      //record Burn event with number of ARX tokens burned
      Burn(msg.sender, usersARXfundValue[msg.sender]);

      //send Eth back
      msg.sender.transfer(ethRefund);

      //record Refund event with number of Eth refunded in transaction
      Refund(msg.sender, ethRefund);
    }
}
