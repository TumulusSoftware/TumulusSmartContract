//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0 <0.9.0;

// import "hardhat/console.sol";

contract Datasitter {
	/// constants for status field across several structs
	uint8 constant NULL = 0; // non-exists
	uint8 constant EXISTING = 1;
	uint8 constant EFFECTIVE = 2;
	uint8 constant ANNOUNCED = 4; // for agreements
	uint8 constant REJECTED = 8; // for agreements
	
	/// max # of bits for User.state. Min 8 Max 256 step 8
	/// If this value is changed, all lines commented with CAUTION-A should be changed too.
	uint8 public constant MAX_USER_STATE = 8;

	uint8 constant AG = 1; // operation is on agreement
	uint8 constant AU = 2; // operation is on authorization
	uint8 constant AS = 4; // operation is on asset
	uint8 constant OW = 8; // operation is by owner

	struct User {
		// Hold the different generic states in one single integer. Each bit means agrm unique state.
		uint8 state; // Type should match MAX_USER_STATE (CAUTION-A) 
	}

	struct State {
		uint8 bit; 
		uint8 threshold;
		uint8 announcementCount;
		bool active;
	}

	struct Asset {
		uint40 id;
		address owner;
		bytes data; // encrypted CID
		uint8 status; // NULL, EXISTING
	}

	// Asset Authorization
	struct Authorization {
		uint40 id;
		address owner;
		address viewer;
		uint8 bit; // 0 .. 255
		uint40 assetId;
		uint8 status; // NULL, EXISTING(created), EFFECTIVE(activated)
	}

	// Announcer Agreement
	struct Agreement {
		uint40 id;
		address owner;
		address announcer;
		uint8 bit; // 0 .. 255
		uint8 status; // NULL, EXISTING(requested), EFFECTIVE(agreed), ANNOUNCED, REJECTED
	}

	// An address type variable is used to store ADMIN account.
	address public admin;
	uint40 private uid; // unique id. up to 1 trillion
	bool meaningless;
	
	mapping(address => User) users; // address => User
	mapping(address => mapping(uint8 => uint8)) thresholdCount; // owner => bit => (thresholdValue - 1)
	mapping(address => mapping(uint8 => uint8)) announcementCount; // owner => bit => # of agreements announced

	mapping(uint40 => Asset) assets;
	mapping(address => uint40[]) assetsByOwner; // owner => assetId[]

	mapping(uint40 => Authorization) authorizations;
	mapping(address => uint40[]) authorizationsByOwner; // owner => authorizationId[]
	mapping(address => uint40[]) authorizationsByViewer; // viewer => authorizationId[]

	mapping(uint40 => Agreement) agreements;
	mapping(address => uint40[]) agreementsByOwner; // owner => agreementId[]
	mapping(address => uint40[]) agreementsByAnnouncer; // announcer => agreementId[]

	event AgreementRequested(uint40 id, address owner, address announcer, uint8 bit);
	event AgreementAgreed   (uint40 id, address owner, address announcer, uint8 bit);
	event AgreementRejected (uint40 id, address owner, address announcer, uint8 bit);
	event AgreementDeleted  (uint40 id, address owner, address announcer, uint8 bit);
	event AgreementAnnounced(uint40 id, address owner, address announcer, uint8 bit);
	event StateRemoved      (uint40 id, address owner, address announcer, uint8 bit);
	event ViewAuthorized    (Authorization[] authorizations);
	event ViewEnded         (Authorization[] authorizations);
	event ViewRevoked       (Authorization[] authorizations);
	event AssetAdded        (uint40 id, uint32 sno);

	/**
	 * Contract initialization.
	 */
	constructor() {
		admin = msg.sender;
		uid = 1;
	}

	modifier adm() {
		require(admin == msg.sender, "NOT_ADM");
		_;
	}

	modifier alive(address owner) {
		require(users[owner].state & 1 == 0, "DEAD");
		_;
	}

	modifier valid(uint40 id, address user, uint8 vType) {
		if (vType & AG == AG) {
			Agreement memory agrm = agreements[id];
			require(agrm.status != NULL, "MISSING");
			address addr = (vType & OW == OW) ? agrm.owner : agrm.announcer;
			require(addr == user, "WRONG_ID");
		}
		if (vType & AU == AU) {
			Authorization memory auth = authorizations[id];
			require(auth.status != NULL, "MISSING");
			address addr = (vType & OW == OW) ? auth.owner : auth.viewer;
			require(addr == user, "WRONG_ID");
			if (vType & OW == 0) require(auth.status & EFFECTIVE == EFFECTIVE, "EXPIRED");
		}
		if (vType & AS == AS && id > 0) {
			Asset memory asset = assets[id];
			require(asset.status != NULL, "MISSING");
			require(asset.owner == user, "WRONG_ID");
		}
		_;
	}

	function getAuthorizationsByOwner(address owner) adm alive(owner) external view returns(Authorization[] memory _rtn) {
		_rtn = getAuthorizationsFromIds(authorizationsByOwner[owner], EXISTING, false, 0);
	}

	function getAuthorizationsByViewer(address viewer) adm external view returns(Authorization[] memory _rtn) {
		_rtn = getAuthorizationsFromIds(authorizationsByViewer[viewer], EFFECTIVE, false, 0);
	}

	function getAuthorizationsFromIds(uint40[] memory ids, uint8 status, bool onBit, uint8 bit) internal view returns(Authorization[] memory _rtn) {
		Authorization[] memory buffer = new Authorization[](ids.length);
		uint40 size = 0;
		for (uint40 i = 0; i < ids.length; i++) {
			Authorization memory auth = authorizations[ids[i]];
			if ((auth.status & status == status) && (onBit ? (auth.bit == bit) : true)) {
				buffer[size++] = auth;
			}
		}
		_rtn = new Authorization[](size);
		for (uint40 i = 0; i < size; i++) {
			_rtn[i] = buffer[i];
		}
	}

	function getAssetData(uint40 id, address owner) adm alive(owner) valid(id, owner, AS) external view returns(bytes memory _rtn) {
		_rtn = assets[id].data;
	}

	function getAuthorizedAssetData(uint40 id, address viewer) adm valid(id, viewer, AU) external view returns(bytes memory _rtn) {
		uint40 assetId = authorizations[id].assetId;
		_rtn = assets[assetId].data;
	}

	function getAgreementsByOwner(address owner) adm alive(owner) external view returns(Agreement[] memory _rtn) {
		_rtn = getAgreementsFromIds(agreementsByOwner[owner]);
	}

	function getAgreementsByAnnouncer(address announcer) adm  external view returns(Agreement[] memory _rtn) {
		_rtn = getAgreementsFromIds(agreementsByAnnouncer[announcer]);
	}

	function getAgreementsFromIds(uint40[] memory ids) internal view returns(Agreement[] memory _rtn) {
		Agreement[] memory buffer = new Agreement[](ids.length);
		uint40 size = 0;
		for (uint40 i = 0; i < ids.length; i++) {
			Agreement memory agrm = agreements[ids[i]];
			if (agrm.status != NULL) {
				buffer[size++] = agrm;
			}
		}
		_rtn = new Agreement[](size);
		for (uint40 i = 0; i < size; i++) {
			_rtn[i] = buffer[i];
		}
	}

	function getStates(address owner) adm alive(owner) external view returns(State[] memory _rtn) {
		_rtn = new State[](MAX_USER_STATE);
		for (uint8 bit = 0; bit < MAX_USER_STATE; bit++) {
			_rtn[bit] = State({
				bit: bit,
				threshold: thresholdCount[owner][bit] + 1,
				announcementCount: announcementCount[owner][bit],
				active: (users[owner].state & (2**bit) != 0)
			});
		}
	}

	function saveAsset(uint40 id, address owner, uint32 sno, bytes calldata data) adm alive(owner) valid(id, owner, AS) external {
		bool exists = (id > 0);
		uint40 _id = exists ? id : ++uid;
		assets[_id] = Asset({
			id: _id,
			owner: owner,
			data: data,
			status: EXISTING
		});
		if (!exists) {
			assetsByOwner[owner].push(_id);
			emit AssetAdded(_id, sno);
		}
	}

	function createAuthorization(address owner, address viewer, uint8 bit, uint40 assetId) adm alive(owner) external {
		// Find a physically existing item matching parameters, either logically existing or deleted
		bool exists = false;
		uint40 existingId = 0;
		uint8 existingStatus = 0;
		uint40[] memory authIds = authorizationsByOwner[owner];
		for (uint40 i = 0; i < authIds.length; i++) {
			Authorization memory auth = authorizations[authIds[i]];
			if (auth.viewer == viewer && auth.bit == bit && auth.assetId == assetId) {
				exists = true;
				existingId = auth.id;
				existingStatus = auth.status;
				break;
			}
		}
		require(!exists || existingStatus == NULL, "DUPLICATE");

		uint40 _id = exists ? existingId : ++uid;
		bool inState = isInState(owner, bit);
		uint8 status = inState ? EFFECTIVE | EXISTING : EXISTING;

		authorizations[_id] = Authorization({
			id: _id,
			owner: owner,
			viewer: viewer,
			bit: bit,
			assetId: assetId,
			status: status
		});

		if (!exists) {
			authorizationsByOwner[owner].push(_id);
			authorizationsByViewer[viewer].push(_id);
		} 

		if (inState) {
			Authorization[] memory auths4event = new Authorization[](1);
			auths4event[0] = authorizations[_id];
			emit ViewAuthorized(auths4event);
		}
	}

	function requestAgreement(address owner, address announcer, uint8 bit) adm alive(owner) external {
		bool exists = false;
		uint40 existingId = 0;
		uint8 existingStatus = 0;
		uint40[] memory agrmIds = agreementsByOwner[owner];
		for (uint40 i = 0; i < agrmIds.length; i++) {
			Agreement memory agrm = agreements[agrmIds[i]];
			if (agrm.announcer == announcer && agrm.bit == bit) {
				exists = true;
				existingId = agrmIds[i];
				existingStatus = agrm.status;
				break;
			}
		}

		require(!exists || existingStatus == NULL || existingStatus & REJECTED == REJECTED, "DUPLICATE");

		uint40 _id = exists ? existingId : ++uid;
		Agreement memory agreement = Agreement({
			id: _id,
			owner: owner,
			announcer: announcer,
			bit: bit,
			status: EXISTING
		});

		agreements[_id] = agreement;
		if (!exists) {
			agreementsByOwner[owner].push(_id);
			agreementsByAnnouncer[announcer].push(_id);
		}

		emit AgreementRequested(_id, owner, announcer, bit);
	}

	function agreeAgreement(uint40 id, address announcer) adm valid(id, announcer, AG) external  {
		Agreement storage agrm = agreements[id];
		address owner = agrm.owner;
		require(agrm.status & EFFECTIVE == 0, "DUPLICATE");
		agrm.status = (agrm.status | EFFECTIVE | REJECTED) - REJECTED;
		emit AgreementAgreed(id, owner, announcer, agrm.bit);
	}

	function rejectAgreement(uint40 id, address announcer) adm valid(id, announcer, AG) external  {
		Agreement storage agrm = agreements[id];
		address owner = agrm.owner;
		require(agrm.status & ANNOUNCED == 0, "ANNOUNCED");
		require(agrm.status & REJECTED == 0, "DUPLICATE");
		agrm.status = (agrm.status | EFFECTIVE | REJECTED) - EFFECTIVE;
		emit AgreementRejected(id, owner, announcer, agrm.bit);
	}

	function deleteAgreement(uint40 id, address owner) adm alive(owner) valid(id, owner, AG|OW) external  {
		Agreement storage agrm = agreements[id];
		if (agrm.status & ANNOUNCED == ANNOUNCED && announcementCount[owner][agrm.bit] > 0) {
				announcementCount[owner][agrm.bit]--;
		}
		agrm.status = NULL;
		emit AgreementDeleted(id, owner, agrm.announcer, agrm.bit);
	}

	function announce(uint40 id, address announcer) adm valid(id, announcer, AG) external  {
		Agreement storage agrm = agreements[id];
		address owner = agrm.owner;
		require(agrm.status & EFFECTIVE == EFFECTIVE, "NOT_AGREED" );
		require(agrm.status & ANNOUNCED == 0, "DUPLICATE" );
		agrm.status |= ANNOUNCED;

		emit AgreementAnnounced(id, owner, announcer, agrm.bit);

		uint8 bit = agrm.bit;
		uint8 anncCount = ++announcementCount[owner][bit]; // with concurrency consideration
		uint8 threshold = thresholdCount[owner][bit] + 1;
		if (anncCount == threshold) {
			activateOwnerState(owner, bit);
		}
	}

	function activateOwnerState(address owner, uint8 bit) internal {
		// set user state value
		users[owner].state |= (uint8)(2**bit); // Type casting should match MAX_USER_STATE (CAUTION-A)

		uint40[] memory authIds = authorizationsByOwner[owner];

		// Activate applicable authorizations
		for (uint40 i = 0; i < authIds.length; i++) {
			uint40 authId = authIds[i];
			Authorization memory auth = authorizations[authId];
			if (auth.bit == bit && auth.status & EXISTING == EXISTING) {
				authorizations[authId].status |= EFFECTIVE;
			}
		}

		Authorization[] memory auths4event = getAuthorizationsFromIds(authIds, EFFECTIVE, true, bit);
		if (auths4event.length > 0) emit ViewAuthorized(auths4event);
	}

	function setThreshold(address owner, uint8 bit, uint8 value) adm alive(owner) external  {
		uint8 anncCount = announcementCount[owner][bit];
		require(value > 0, "VAL_INVALID");
		require(thresholdCount[owner][bit] + 1 != value, "VAL_SAME");
		thresholdCount[owner][bit] = value - 1; 

		if (anncCount >= value && users[owner].state & 2**bit == 0) {
			// triggers authorization
			activateOwnerState(owner, bit);
		}
	}

	function isInState(address owner, uint8 bit) internal view returns(bool) {
		return (users[owner].state & 2**bit != 0);
	}

	function removeState(address owner, uint8 bit) adm alive(owner) external  {
		require(isInState(owner, bit), "WRONG_STATE");
		users[owner].state -= (uint8)(2**bit); // Type casting should match MAX_USER_STATE (CAUTION-A) (CAUTION-A)

		uint40[] memory authIds = authorizationsByOwner[owner];

		// reset authorization
		Authorization[] memory auths4event = getAuthorizationsFromIds(authIds, EFFECTIVE, true, bit);
		if (auths4event.length > 0) {
			for (uint40 i = 0; i < auths4event.length; i++) {
				Authorization memory auth = auths4event[i];
				auth.status -= EFFECTIVE;
				authorizations[auth.id].status -= EFFECTIVE;
			}
			emit ViewEnded(auths4event);
		}

		// reset announcements
		announcementCount[owner][bit] = 0;
		for (uint40 i = 0; i < agreementsByOwner[owner].length; i++) {
			uint40 agrmId = agreementsByOwner[owner][i];
			Agreement memory agrm = agreements[agrmId];
			if (agrm.bit == bit && agrm.status & ANNOUNCED == ANNOUNCED) {
				agreements[agrmId].status -= ANNOUNCED;
				emit StateRemoved(agrmId, owner, agrm.announcer, bit);
			}
		}
	}

	function removeAuthorization(uint40 id, address owner) adm alive(owner) valid(id, owner, AU|OW) external  {
		authorizations[id].status = NULL;
		Authorization[] memory auths4event = new Authorization[](1);
		auths4event[0] = authorizations[id];
		emit ViewRevoked(auths4event);
	}

	function burnNonce() external {
		meaningless = !meaningless;
	}
}
