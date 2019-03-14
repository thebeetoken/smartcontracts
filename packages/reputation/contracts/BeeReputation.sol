/************************
 * Version 0.0 of Bee Reputation
 */

pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

// interface definition for a scorer
contract BeeScorerInterface {
    function score(uint256 _reviewTotal,
        uint256 _reviewCount,
        uint256 _personalTotal,
        uint256 _personalCount,
        uint256 _bookingTotal,
        uint256 _bookingCount,
        uint256 _miscTotal,
        uint256 _miscCount,
        uint256 _userScore) external pure returns (uint256);
}

contract SimpleBeeScorer is BeeScorerInterface {
        function score(uint256 _reviewTotal,
        uint256 _reviewCount,
        uint256 _personalTotal,
        uint256 _personalCount,
        uint256 _bookingTotal,
        uint256 _bookingCount,
        uint256 _miscTotal,
        uint256 _miscCount,
        uint256 _userScore) external pure returns (uint256) {
            if(_personalCount==0) {
                return 0;
            }
            return SafeMath.div(_personalTotal, _personalCount);
        }
}


contract BeeReputation is Ownable {
    
    struct UserSummary {
        uint256 reviewTotal;
        uint256 reviewCount;
        uint256 personalTotal;
        uint256 personalCount;
        uint256 bookingTotal;
        uint256 bookingCount;
        uint256 miscTotal;
        uint256 miscCount;
        uint256 userScore;
    }
    
    // Events
    event Signal (
        address source,
        address target,
        uint8 signalType,
        bytes32 id,
        bytes32 hashedData, // e.g., hashed review text; hashed reason for providing user the score; etc.
        uint8 score 
    );
    event ScoreUpdate (
        bytes32 signalId,
        uint256 oldUserScore,
        uint256 newUserScore
    );
    
    // constants
    uint8 public MAX_SIGNAL_SCORE = 100;
    
    // mappings
    mapping (address=>UserSummary) userToSummary;
    mapping (uint8=>string) signalTypeMapping;
    mapping(bytes32=>bool) seenIds;
    
    // list of all user addresses that summaries are available for
    address[] private seenUsers;
    
    // Scorer
    BeeScorerInterface private scorer;
    
    constructor() public {
        signalTypeMapping[0x0] = 'review';   // e.g., host provides review; guest provides a review
        signalTypeMapping[0x1] = 'personal'; // e.g., when a user updates their profile, adds number, etc
        signalTypeMapping[0x2] = 'booking';  // e.g., when a user makes, cancels, rejects a booking
        signalTypeMapping[0x3] = 'misc';     // miscellanous items
    }
    
    // informs the protocol that a new signal has been observed
    // inputs:
    //   * address _source -- address of entity providing signal (e.g., admin, host, guest)
    //   * address _target -- address of entity the signal is targeted for
    //   * uint8 _signalType -- one of the following keys: {0=>review, 1=>personal, 2=>booking, 3=>misc}
    //   * bytes32 _id       -- unique id of this signal
    //   * bytes32 _hashedData (Optional) -- any hashed data (e.g., hashed text review)
    //   * uint8 _score -- value between 0 and 100 to denote how positive the signal is (100 being extremely positive)
    function addSignal(address _source, address _target, uint8 _signalType, bytes32 _id, bytes32 _hashedData, uint8 _score) external {
        require(!seenIds[_id], 'id already used');
        require(_signalType >= 0x0 && _signalType <= 0x3,'invalid value for signalType');
        require(_score >= 0 && _score <= MAX_SIGNAL_SCORE, 'score must be between 0-MAX_SIGNAL_SCORE(e.g., 100)');
        
        emit Signal(_source, _target, _signalType, _id, _hashedData, _score);
        
        // fetch user summary
        UserSummary storage summary = userToSummary[_target];
        // update seenUsers if the user has never been seen before
        if(_isNewUser(summary)){
            seenUsers.push(_target);
        }
        
        // update user's summary
        if(_signalType == 0x0) {
            summary.reviewTotal = SafeMath.add(summary.reviewTotal, _score);
            summary.reviewCount = SafeMath.add(summary.reviewCount, 1);
        } else if (_signalType == 0x1) {
            summary.personalTotal = SafeMath.add(summary.personalTotal, _score);
            summary.personalCount = SafeMath.add(summary.personalCount, 1);
        } else if (_signalType == 0x2) {
            summary.bookingTotal = SafeMath.add(summary.bookingTotal, _score);
            summary.bookingCount = SafeMath.add(summary.bookingCount, 1);
        } else {
            summary.miscTotal = SafeMath.add(summary.miscTotal, _score);
            summary.miscCount = SafeMath.add(summary.miscCount, 1);
        }
        
        // update user's score
        uint256 oldUserScore = summary.userScore;
        summary.userScore = _computeScore(summary);
        
        emit ScoreUpdate(_id, oldUserScore, summary.userScore);
        
        // update list of seen bookingIds
        seenIds[_id] = true;

    }
    
    // Computes a user's current score given a UserSummary object. Returns value between 0-100.
    function _computeScore(UserSummary _summary) internal view returns (uint256) {
        if(address(scorer) != 0x0){
            return scorer.score(_summary.reviewTotal,
                                            _summary.reviewCount,
                                            _summary.personalTotal,
                                            _summary.personalCount,
                                            _summary.bookingTotal,
                                            _summary.bookingCount,
                                            _summary.miscTotal,
                                            _summary.miscCount,
                                            _summary.userScore);
        }
        // default scoring just relies on reviews -- will ignore other features for now.
        if(_summary.reviewCount == 0){
            return 0;
        }
        // We want to return a score (from 0-100) which represents how "close to perfect" a user's culmulative rating history is.
        // To do so, we will use the following scoring function:
        // * culmTotal = sum of all *Total fields;
        // * culmCount = sum of all *Count fields;
        // * score = (culmTotal * 100) / (culmCount * MAX_SIGNAL_SCORE)
        uint256 culmTotal = SafeMath.add(SafeMath.add(SafeMath.add(_summary.reviewTotal, _summary.personalTotal), _summary.bookingTotal), _summary.miscTotal);
        uint256 culmCount = SafeMath.add(SafeMath.add(SafeMath.add(_summary.reviewCount, _summary.personalCount), _summary.bookingCount), _summary.miscCount);
        return SafeMath.div(SafeMath.mul(culmTotal, 100), SafeMath.mul(culmCount, MAX_SIGNAL_SCORE));
    }
    
    // determines whether or not the summary object is indicative of a new user;
    function _isNewUser(UserSummary _summary) internal pure returns (bool) {
        return (_summary.reviewCount == 0 && _summary.personalCount == 0 && _summary.bookingCount == 0 && _summary.miscCount == 0);
    }
    
    ////////////////////////////////////////////////
    // Intefaces as described in the white paper  //
    ////////////////////////////////////////////////
    
    // fetches user's reputation score along with summary of contributing factors (as described in white paper)
    function pullReputationScore(address _target) public view returns (
        uint256 reviewTotal,
        uint256 reviewCount,
        uint256 personalTotal,
        uint256 personalCount,
        uint256 bookingTotal,
        uint256 bookingCount,
        uint256 miscTotal,
        uint256 miscCount,
        uint256 userScore
    ) {
        UserSummary storage summary = userToSummary[_target];
        reviewTotal = summary.reviewTotal;
        reviewCount = summary.reviewCount;
        personalTotal = summary.personalTotal;
        personalCount = summary.personalCount;
        bookingTotal= summary.bookingTotal;
        bookingCount = summary.bookingCount;
        miscTotal = summary.miscTotal;
        miscCount = summary.miscCount;
        userScore = summary.userScore;
    }
    
    // updates scorer and applies new scorer to all users (as described in White Paper)
    function updateReputationScore (address _scorer) public onlyOwner() {
        // update scorer
        scorer = BeeScorerInterface(_scorer);
        // update scores for all users
        uint256 nUsers = seenUsers.length;
        for (uint256 ind=0; ind < nUsers; ind++) {
            address target = seenUsers[ind];
            UserSummary storage summary = userToSummary[target];
            summary.userScore = _computeScore(summary);
        }
    }
}
