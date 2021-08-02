pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";


contract Insurance is ChainlinkClient {
    struct Policy {
        uint256 id;
        uint256 price;
        string url;
        string data;
    }

    struct Claim {
        uint256 id;
        address by;
        address to;
        string reason;
        bool isApproved;
        bool isDenied;
        uint256 timestamp;
    }

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    // Policy ID => policy data url outside
    mapping (uint256 => Policy) public policies;
    // Buyer address => policy ID
    mapping (address => uint256) public policyByOwner;
    mapping (address => bool) public managers;
    address public owner;
    uint256 public lastPolicyId = 1;
    uint256 public updatingPolicy;
    string public latestDataPolicy;
    uint256 public policyCost = 0.1 ether;
    Claim[] public claims;

    event ReceivedPolicyData(string _data);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyManager {
        require(managers[msg.sender]);
        _;
    }

    constructor () public {
        owner = msg.sender;
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    function addOrRemoveManager(address _to, bool _add) public onlyOwner {
        managers[_to] = _add;
    }

    /*receive() external payable {
        // React to receiving ether
    }*/

    // Allow specific users to create insurance policies 1, 2
    function createPolicy(string memory _url) public onlyOwner {
        Policy memory my = Policy(lastPolicyId, 0.1 ether, _url, '');
        policies[lastPolicyId] = my;
        lastPolicyId++;
    }

    function updatePolicy(uint256 _id) public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        //provable_query("URL", policies[_id].url, 500000);
        //provable_query("URL", policies[_id].url, 500000);
        request.add("get", policies[_id].url);
        updatingPolicy = _id;

        return sendChainlinkRequestTo(oracle, request, fee);
    }


  /* function __callback(bytes32 myid, string memory result) public override {
        if (msg.sender != provable_cbAddress()) revert();
        policies[updatingPolicy].data = result;
        emit ReceivedPolicyData(result);
   } */

    function fulfill(bytes32 myid, uint256 _volume) public recordChainlinkFulfillment(myid)
    {
        uint256 volume = _volume;

    }

    /**
     * Withdraw LINK from this contract
     *
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawLink() external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }

   function getAllPolicies() public view returns (string[] memory) {
       string[] memory _policies;
       for(uint256 i = 0; i < lastPolicyId; i++) {
           _policies[i] = policies[i].url;
       }
       return _policies;
   }

   // Then allow other users to buy those policies
   function buyPolicy(uint256 _id) public payable {
       require(msg.value >= policyCost);
       policyByOwner[msg.sender] = _id;
   }

    // Finally allow those buyers to create claims that will either pay them or request them a payment
    function createClaim(address _payer, string memory _reason) public {
        require(policyByOwner[msg.sender] != 0, 'You must have a policy to make a claim');
        Claim memory myClaim = Claim(claims.length, msg.sender, _payer, _reason, false, false, now);
        claims.push(myClaim);
    }

    function approveOrDenyClaim(uint256 _id, bool _isApproved) public onlyManager {
        if (_isApproved) {
            claims[_id].isApproved = true;
        } else {
            claims[_id].isDenied = true;
        }
    }

    function getClaims() public view returns(Claim[] memory) {
        return claims;
    }
}
