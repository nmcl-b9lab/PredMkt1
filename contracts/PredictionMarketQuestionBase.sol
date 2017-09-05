pragma solidity 0.4.15;

import "./PausableByOwner.sol";

// Base contract for predictions.
// TODO: a pricing algorithm  perhaps as an inheriting contract that overrides predict() and resolve().
// Inthis naive base contract, all correct predictions receive the same share of the
// available funds, regardless of when they were made.
// This makes for a terrible prediction market which offers no incentive to make early predictions. 
/// @author Neil McLaren
contract PredictionMarketQuestionBase is PausableByOwner() {

    bytes32 public questionTextHash;
    address public trustedOracle;
    address public owner;
    uint    public closesToPredictionsAtTimestamp;
    uint    public ownerClaimsAllFundsTimestamp;
    bool    public payoutToYesPredictions;
    bool    public payoutToNoPredictions;
    uint    public ownerIsDueWei;
    uint    public correctPredictionIsDueWeiPerEther;
    uint    public constant WEI_PER_ETHER                     = 1000000000000000000;
    uint    public constant MIN_STAKE_IN_WEI                  = 1000000000000000;
    uint    public constant OWNER_COMMISSION_IN_WEI_PER_ETHER = 10000000000000000;

    // All funds left in the contract can be claimed by the owner one year after resolution
    // TODO: how to mock this for testing?
    uint    public constant SECONDS_PER_YEAR                  = 60 * 60 * 24 * 365;

    // Extend with care. Mapping of predictions assumes that these enum values all fit into uint8.
    // Also, extending the logic to allow an arbitrary number of outcomes requires significant rework,
    // including:
    //  - updates to all code that deals with multiple Outcomes (e.g. claimReward()), because there
    // is no way to loop over all Outcomes without explicitly listing them.
    //  - A new pricing algorithm for any child contract that actually implements one.
    enum Outcome {UNRESOLVED, YES, NO, UNDECIDEABLE}
    Outcome resolution;

    struct OutcomeData {
        uint predictedWei;
        mapping(address => uint) predictions;
    }

    // Mapping from each Outcome (must cast to uint8) to a map of OutcomeData for that resoltion
    mapping(uint8 => OutcomeData) outcomes; 

    // The question text is not saved but can be retrieved using this event
    event LogQuestionCreated(address indexed _owner, string _questionText);

    // Logs event resolution (can only happen once)
    event LogResolution(address indexed resolver, Outcome indexed _resolution);

    // Logs all predictions that are made
    event LogPrediction(address indexed predictedBy, Outcome indexed predictedResolution, uint valueInWei);

    function resolved()
        constant // TODO: change to view
        notWhilePaused
        returns (bool)
    {
        return resolution != Outcome.UNRESOLVED;
    }

    // Constructor
    function PredictionMarketQuestionBase(string _questionText,
                            address _trustedOracle,
                            uint    _closesToPredictionsAtTimestamp) {
        owner = msg.sender;
        questionTextHash = sha3(_questionText);
        trustedOracle = _trustedOracle;
        closesToPredictionsAtTimestamp = _closesToPredictionsAtTimestamp;
        resolution = Outcome.UNRESOLVED;
        LogQuestionCreated(owner, _questionText);
    }

    modifier onlyBy(address account)
    {
        require(msg.sender == account);
        _;
    }

    function isOpenForPredictions()
        public
        constant //TODO: view
        returns (bool result)
    {
        return ((now < closesToPredictionsAtTimestamp) && !resolved());
    }

    function resolve(Outcome _resolution)
        public
        notWhilePaused
        onlyBy(trustedOracle)
    {
        require(!isOpenForPredictions() && !resolved());
        LogResolution(msg.sender, _resolution);
        resolution = _resolution;
        ownerClaimsAllFundsTimestamp = now + SECONDS_PER_YEAR;

        if (resolution == Outcome.UNDECIDEABLE) {
            // Everyone is refunded, and owner gets nothing.
            // Owner should have been more precise.
            correctPredictionIsDueWeiPerEther = WEI_PER_ETHER;
            ownerIsDueWei = 0;
        } else {
            // Owner gets 1% of the contract balance before any payout
            // Action this later. Doing so now would make a failed send (e.g. out of gas) blocking
            // TODO: SafeMath
            ownerIsDueWei = (this.balance * OWNER_COMMISSION_IN_WEI_PER_ETHER) / WEI_PER_ETHER;

            if (resolution == Outcome.YES && outcomes[uint8(Outcome.YES)].predictedWei > 0) {
                // TODO: SafeMath
                correctPredictionIsDueWeiPerEther = (this.balance * (WEI_PER_ETHER - OWNER_COMMISSION_IN_WEI_PER_ETHER)) // commission factor
                                                    / outcomes[uint8(Outcome.YES)].predictedWei; // success factor
            } else if (resolution == Outcome.NO && outcomes[uint8(Outcome.NO)].predictedWei > 0) {
                // TODO: SafeMath
                correctPredictionIsDueWeiPerEther = (this.balance * (WEI_PER_ETHER - OWNER_COMMISSION_IN_WEI_PER_ETHER)) // commission factor
                                                    / outcomes[uint8(Outcome.NO)].predictedWei; // success factor
            }  
        }   
    }

    function predictYES()
        public
        notWhilePaused
        payable
    {
        predict(Outcome.YES);
    }

    function predictNO()
        public
        notWhilePaused
        payable
    {
        predict(Outcome.NO);
    }

    // Naive, with terrible prediction incentivisation. Should be overridden by meaningful implementations.
    function predict(Outcome _outcome)
        notWhilePaused
        internal
    {
        require(isOpenForPredictions());
        require(_outcome != Outcome.UNRESOLVED);
        require(msg.value > MIN_STAKE_IN_WEI);
        // TODO: also disallow predictions of UNDECIDEABLE?
        outcomes[uint8(_outcome)].predictions[msg.sender] += msg.value;
        outcomes[uint8(_outcome)].predictedWei += msg.value;
        LogPrediction(msg.sender, _outcome, msg.value);
    }

    function claimPayout(address predictor)
        public
        notWhilePaused
    {
        require(!isOpenForPredictions());
        require(resolution != Outcome.UNRESOLVED);
        uint paidIn;

        if (resolution == Outcome.UNDECIDEABLE) {
            // Special case. Refund both YES and NO predictions, in full.
            paidIn = outcomes[uint8(Outcome.YES)].predictions[predictor] + outcomes[uint8(Outcome.NO)].predictions[predictor];
            outcomes[uint8(Outcome.YES)].predictions[predictor] = 0;
            outcomes[uint8(Outcome.NO)].predictions[predictor] = 0;
        } else if (resolution == Outcome.YES) {
            paidIn = outcomes[uint8(Outcome.YES)].predictions[predictor];
            outcomes[uint8(Outcome.YES)].predictions[predictor] = 0;
        } else if (resolution == Outcome.NO) {
            paidIn = outcomes[uint8(Outcome.NO)].predictions[predictor];
            outcomes[uint8(Outcome.NO)].predictions[predictor] = 0;

        }

        // Scale the input amount to get an output amount, then pay it.
        // TODO: SafeMath
        var payout = (paidIn * correctPredictionIsDueWeiPerEther) / WEI_PER_ETHER;
        assert(payout <= paidIn);
        predictor.transfer(payout);

        // TODO: event
    }


    function claimOwnerFee()
        public
        notWhilePaused
    {
        require(!isOpenForPredictions());
        require(resolved());
        require(ownerIsDueWei > 0);
        var sendWei = ownerIsDueWei;
        ownerIsDueWei = 0;
        owner.transfer(sendWei);

        // TODO: event
    }

    // TODO: override (un)pause() to result in better behaviour
    // At a minimum, delay the earliest suicide date to one year after the unpausing
    // But is this sufficiently fair? How to we ensure owner() doesn't abuse pause() to maximise
    // his own winnings (perhaps from a prediction made by another account)

    // Claim any excess ether - e.g. rounding errors, unclaimed payouts, & ether suicided to contract after payout calculations
    function killSelf()
        // Only the owner can choose to selfdestruct, because contract might still receive ether inadvertantly from other suicides
        // and once we suicide such income becomes forever unrecoverable
        public
        notWhilePaused
        onlyOwner 
    {
        require(!isOpenForPredictions());
        require(resolved());
        require(now > ownerClaimsAllFundsTimestamp);
        // TODO: event
        selfdestruct(owner);
    }
        


    
    
  

}