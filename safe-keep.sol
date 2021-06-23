// SPDX-License-Identifier: MIT
pragma solidity >=0.6.11 <0.6.12;
pragma experimental ABIEncoderV2;

abstract contract ERC20Token {
    function symbol() public virtual view returns (string memory);
}

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Owner {

    address private owner;

    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);

    // modifier to check if caller is owner
    modifier isOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    /**
     * @dev Set contract deployer as owner
     */
    constructor() public {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}

contract SafeKeep is Owner {
  struct record {
    uint256 starttime;
    uint256 endtime;
    uint256 cycle_time;
    address contractaddr;
    uint256 quantity;
    string symbol;
    bool repeat;
    uint256 ex_id;
  }

  struct depositRecord {
    uint256 starttime;
    uint256 quantity;
  }

  struct addrFlag {
    address addr;
    bool deleted;
  }

  struct recordFlag {
    uint256 starttime;
    bool deleted;
  }

  struct tokenMsg {
    address[] tokens;
    mapping (address => uint256) index_map;
    mapping (address => bool) token;
  }
  tokenMsg tokenData;

  struct keepMsg {
    mapping (address => record[]) keeps;
    mapping (address => mapping (uint256 => uint256))  index_map;
    mapping (address => mapping (uint256 => record))  records; 
  }
  keepMsg keepData;

  struct depositMsg {
    mapping (address => depositRecord[]) deposits;
    mapping (address => mapping (uint256 => uint256))  index_map;
    mapping (address => mapping (uint256 => depositRecord))  depositRecords; 
  }
  depositMsg depositData;

  address public yefi_con; 
  uint256 public cycle_time; 
  uint256 public cycle_time2; 
  bool public allow_token; 

  event keepe(address indexed user, uint256 indexed starttime, uint256 endtime, address contractaddr, uint256 quantity, uint256 depositquantity, string symbol, bool repeat, uint256 ex_id);
  event withdrawe(address indexed user, uint256 indexed starttime);

  constructor(uint256 _cycleTime, uint256 _cycleTime2, bool _allowToken, address _yefi) public {
      cycle_time = _cycleTime;
      cycle_time2 = _cycleTime2;
      allow_token = _allowToken;
      yefi_con = _yefi;
  }

  function accept() public payable {
  }

  function transferToken(address _contractaddr, address _to, uint256 _value) public isOwner {
    safeTransfer(_contractaddr, _to, _value);
  }

  function transfer(address payable _to, uint256 _value) public isOwner {
    _to.transfer(_value);
  }

  function setCycleTime(uint256 _time, uint256 _cycleTime2) public isOwner {
    require(_time > 0, 'time must be greater than 0');
    require(_cycleTime2 > 0, 'time must be greater than 0');
    cycle_time = _time;
    cycle_time2 = _cycleTime2;
  }

  function setYefiCon(address _yefi) public isOwner {
    require(_yefi != address(0), 'wrong yefi_con');
    yefi_con = _yefi;
  }

  function setAllowToken(bool _allow) public isOwner {
    require(_allow != allow_token, 'cannot change to the same');
    allow_token = _allow;
  }

  function addToken(address _contractaddr) public isOwner {
    require(_contractaddr != address(0), 'wrong contractaddr');
    require(!tokenData.token[_contractaddr], 'token already add');
    uint256 indexKey = tokenData.index_map[_contractaddr];
    tokenData.tokens.push(_contractaddr);
    indexKey = tokenData.tokens.length - 1;
    tokenData.index_map[_contractaddr] = indexKey;
    tokenData.token[_contractaddr] = true;
  }

  function removeToken(address _contractaddr) public isOwner {
    require(tokenData.token[_contractaddr], 'token not add');
    uint256 indexKey = tokenData.index_map[_contractaddr];
    if (indexKey < tokenData.tokens.length - 1) {
      address lastAddr = tokenData.tokens[tokenData.tokens.length - 1];
      tokenData.tokens[indexKey] = tokenData.tokens[tokenData.tokens.length - 1];
      tokenData.tokens.pop();
      tokenData.index_map[lastAddr] = indexKey;
    } else {
      tokenData.tokens.pop();
    }
    delete tokenData.index_map[_contractaddr];
    delete tokenData.token[_contractaddr];
  }

  function getTokensCount() public view returns (uint256) {
    return tokenData.tokens.length;
  }

  function getTokensArr() public view returns (address[] memory) {
    return tokenData.tokens;
  }

  function getTokenAddr(uint256 indexKey) public view returns (address) {
    require(indexKey < tokenData.tokens.length, 'wrong indexKey');
    return tokenData.tokens[indexKey];
  }

  function isAddressAdd(address addr) public view returns (bool) {
    return tokenData.token[addr];
  }

  function changeRepeat(uint256 _starttime, bool _repeat) public {
    require(keepData.records[msg.sender][_starttime].starttime > 0, 'record of the starttime is not exists');
    require(keepData.records[msg.sender][_starttime].repeat != _repeat, 'cannot change to the same repeat');

    if (_repeat) {
      require(keepData.records[msg.sender][_starttime].endtime >= now, 'It cannot be re opened after the end time');
    } else {
      while (keepData.records[msg.sender][_starttime].endtime < now) {
        keepData.records[msg.sender][_starttime].endtime += keepData.records[msg.sender][_starttime].cycle_time;
      }
    }
    keepData.records[msg.sender][_starttime].repeat = _repeat;
    uint256 keyIndex = keepData.index_map[msg.sender][_starttime];
    keepData.keeps[msg.sender][keyIndex].repeat = _repeat;
    keepData.keeps[msg.sender][keyIndex].endtime = keepData.records[msg.sender][_starttime].endtime;
  }

  function keep(address _contractaddr, uint256 _value, bool _repeat, uint256 _depositValue, uint256 _exId, int8 _keepType) public {
    require(tokenData.token[_contractaddr], 'token not add');

    ERC20Token con = ERC20Token(_contractaddr);
    safeTransferFrom(_contractaddr, msg.sender, address(this), _value);
    string memory sym = con.symbol();

    safeTransferFrom(yefi_con, msg.sender, address(this), _depositValue);

    uint256 now_time = now;

    uint256 cycleTime;
    if (_keepType == 1) {
      cycleTime = cycle_time;
    } else {
      cycleTime = cycle_time2;
    }

    depositData.depositRecords[msg.sender][now_time] = depositRecord(now_time,  _depositValue);
    depositData.deposits[msg.sender].push(depositRecord(now_time,  _depositValue));
    depositData.index_map[msg.sender][now_time] = depositData.deposits[msg.sender].length - 1;
    keepData.records[msg.sender][now_time] = record(now_time, now_time + cycleTime, cycleTime, _contractaddr, _value, sym, _repeat, _exId);
    keepData.keeps[msg.sender].push(record(now_time, now_time + cycleTime, cycleTime, _contractaddr, _value, sym, _repeat, _exId));
    keepData.index_map[msg.sender][now_time] = keepData.keeps[msg.sender].length - 1;

    emit keepe(msg.sender, now_time, now_time + cycleTime, _contractaddr, _value, _depositValue, sym, _repeat, _exId);
  }

  function keepToken(uint256 _value, bool _repeat, uint256 _depositValue, uint256 _exId, int8 _keepType) public payable {
    require(allow_token, 'This token is not supported');
    require(_value == msg.value, 'wrong value');

    safeTransferFrom(yefi_con, msg.sender, address(this), _depositValue);

    uint256 now_time = now;

    uint256 cycleTime;
    if (_keepType == 1) {
      cycleTime = cycle_time;
    } else {
      cycleTime = cycle_time2;
    }
    depositData.depositRecords[msg.sender][now_time] = depositRecord(now_time,  _depositValue);
    depositData.deposits[msg.sender].push(depositRecord(now_time,  _depositValue));
    depositData.index_map[msg.sender][now_time] = depositData.deposits[msg.sender].length - 1;
    keepData.records[msg.sender][now_time] = record(now_time, now_time + cycleTime, cycleTime, address(0), _value, 'BNB', _repeat, _exId);
    keepData.keeps[msg.sender].push(record(now_time, now_time + cycleTime, cycleTime, address(0), _value, 'BNB', _repeat, _exId));
    keepData.index_map[msg.sender][now_time] = keepData.keeps[msg.sender].length - 1;

    emit keepe(msg.sender, now_time, now_time + cycleTime, address(0), _value, _depositValue, 'BNB', _repeat, _exId);
  }

  function withdraw(uint256 _starttime) public {
    require(keepData.records[msg.sender][_starttime].starttime > 0, 'record of the starttime is not exists');
    require(depositData.depositRecords[msg.sender][_starttime].starttime > 0, 'depositRecord of the starttime is not exists');
    require(!keepData.records[msg.sender][_starttime].repeat, 'cannot withdraw when repeat is open');
    require(now > keepData.records[msg.sender][_starttime].endtime, 'It is not due and cannot be retrieved');

    safeTransfer(keepData.records[msg.sender][_starttime].contractaddr, msg.sender, keepData.records[msg.sender][_starttime].quantity);

    uint256 keyIndex = keepData.index_map[msg.sender][_starttime];
    if (keyIndex < keepData.keeps[msg.sender].length - 1) {
      uint256 lastStartTime = keepData.keeps[msg.sender][keepData.keeps[msg.sender].length - 1].starttime;
      keepData.keeps[msg.sender][keyIndex] = keepData.keeps[msg.sender][keepData.keeps[msg.sender].length - 1];
      keepData.keeps[msg.sender].pop();
      keepData.index_map[msg.sender][lastStartTime] = keyIndex;
    } else {
      keepData.keeps[msg.sender].pop();
      delete keepData.index_map[msg.sender][_starttime];
    }
    delete keepData.records[msg.sender][_starttime];

    safeTransfer(yefi_con, msg.sender, depositData.depositRecords[msg.sender][_starttime].quantity);

    keyIndex = depositData.index_map[msg.sender][_starttime];
    if (keyIndex < depositData.deposits[msg.sender].length - 1) {
      uint256 lastStartTime = depositData.deposits[msg.sender][depositData.deposits[msg.sender].length - 1].starttime;
      depositData.deposits[msg.sender][keyIndex] = depositData.deposits[msg.sender][depositData.deposits[msg.sender].length - 1];
      depositData.deposits[msg.sender].pop();
      depositData.index_map[msg.sender][lastStartTime] = keyIndex;
    } else {
      depositData.deposits[msg.sender].pop();
      delete depositData.index_map[msg.sender][_starttime];
    }
    delete depositData.depositRecords[msg.sender][_starttime];

    emit withdrawe(msg.sender, _starttime);
  }

  function withdrawToken(uint256 _starttime) public {
    require(keepData.records[msg.sender][_starttime].starttime > 0, 'record of the starttime is not exists');
    require(depositData.depositRecords[msg.sender][_starttime].starttime > 0, 'depositRecord of the starttime is not exists');
    require(!keepData.records[msg.sender][_starttime].repeat, 'cannot withdraw when repeat is open');
    require(now > keepData.records[msg.sender][_starttime].endtime, 'It is not due and cannot be retrieved');

    msg.sender.transfer(keepData.records[msg.sender][_starttime].quantity);

    uint256 keyIndex = keepData.index_map[msg.sender][_starttime];
    if (keyIndex < keepData.keeps[msg.sender].length - 1) {
      uint256 lastStartTime = keepData.keeps[msg.sender][keepData.keeps[msg.sender].length - 1].starttime;
      keepData.keeps[msg.sender][keyIndex] = keepData.keeps[msg.sender][keepData.keeps[msg.sender].length - 1];
      keepData.keeps[msg.sender].pop();
      keepData.index_map[msg.sender][lastStartTime] = keyIndex;
    } else {
      keepData.keeps[msg.sender].pop();
      delete keepData.index_map[msg.sender][_starttime];
    }
    delete keepData.records[msg.sender][_starttime];

    safeTransfer(yefi_con, msg.sender, depositData.depositRecords[msg.sender][_starttime].quantity);

    keyIndex = depositData.index_map[msg.sender][_starttime];
    if (keyIndex < depositData.deposits[msg.sender].length - 1) {
      uint256 lastStartTime = depositData.deposits[msg.sender][depositData.deposits[msg.sender].length - 1].starttime;
      depositData.deposits[msg.sender][keyIndex] = depositData.deposits[msg.sender][depositData.deposits[msg.sender].length - 1];
      depositData.deposits[msg.sender].pop();
      depositData.index_map[msg.sender][lastStartTime] = keyIndex;
    } else {
      depositData.deposits[msg.sender].pop();
      delete depositData.index_map[msg.sender][_starttime];
    }
    delete depositData.depositRecords[msg.sender][_starttime];

    emit withdrawe(msg.sender, _starttime);
  }

  function getKeepRecords(address addr) public view returns (record[] memory) {
    return keepData.keeps[addr];
  }

  function getDepositRecords(address addr) public view returns (depositRecord[] memory) {
    return depositData.deposits[addr];
  }

  function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferToken(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

}
