pragma solidity 0.4.15;

import "./PausableByOwner.sol";

// QUESTION: advice from ROb's code review was to add some bool return codes.
// But all my functions either succeed or *throw*.
// Are there particular functions/cicumstances where it would be better to return false than throw,
// e.g. when a failure is not caller's fault.
// For functions where there are no such circumstances, should I still add a bool return, and if so why?

// Base contract for predictions.
// TODO: a pricing algorithm  perhaps as an inheriting contract that overrides predict() and resolve().
// Inthis naive base contract, all correct predictions receive the same share of the
// available funds, regardless of when they were made.
// This makes for a terrible prediction market which offers no incentive to make early predictions. 
/// @author Neil McLaren
contract PredictionMarketQuestionBase is PausableByOwner() {

    // We store a hash for easy comparison, but neither hash nor qn text are essential
    bytes32 public questionTextHash;

    // The Trusted Oracle decides on the result
    address public trustedOracle;

    // The sponsor's (question creator's) deposit is refunded
    // iff resolution is decideable, i.e. unambiguous
    address public sponsor;
    uint    public sponsorDepositWei;

    // Predictions are no longer allowed when we hit this block timestamp
    uint    public closesToPredictionsAtTimestamp;


    uint    public ownerClaimsAllFundsTimestamp;

    uint    public payoutMultiplierInBasisPoints;
    uint    public totalCollectedWei;

    // CONSTANTS (for now). TODO: make configurable
    uint    public constant BASIS_POINTS_SPONSOR_COMMISSION   = 60; // 0.6%. 
    uint    public constant BASIS_POINTS_OWNER_COMMISSION     = 40; // 0.4%.
    uint    public constant MIN_STAKE_IN_WEI                  = 1000000000000000;
    // All funds left in the contract can be claimed by the sponsor one year after resolution
    // TODO: how to mock this for testing?
    uint    public constant SECONDS_PER_YEAR                  = 60 * 60 * 24 * 365;

    // Constants.
    uint    public constant ONE_HUNDRED_PERCENT_IN_BASIS_POINTS= 100 * 100;
    uint    public constant COMMISSION_ADJUSTED_PAYOUT_MULTIPLIER_IN_BASIS_POINTS =
                                ONE_HUNDRED_PERCENT_IN_BASIS_POINTS
                                - (BASIS_POINTS_SPONSOR_COMMISSION + BASIS_POINTS_OWNER_COMMISSION);



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

    // Payout after resolution. May includes commission and/or returned deposits.
    mapping(address => uint) payoutInWei; 

    // The question text is not saved but can be retrieved using this event
    event LogQuestionCreated(address indexed _owner, address indexed _sponsor, string _questionText);

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
    function PredictionMarketQuestionBase(
                            address _sponsor,
                            string _questionText,
                            address _trustedOracle,
                            uint    _closesToPredictionsAtTimestamp)
        payable
    {
        // TODO: make this payable and
        // TODO: give the owner a cut of the profits
        sponsorDepositWei = msg.value;
        owner = msg.sender;
        sponsor = _sponsor;
        questionTextHash = sha3(_questionText);
        trustedOracle = _trustedOracle;
        closesToPredictionsAtTimestamp = _closesToPredictionsAtTimestamp;
        resolution = Outcome.UNRESOLVED;
        LogQuestionCreated(owner, _sponsor, _questionText);
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
        require(_resolution != Outcome.UNRESOLVED);
        assert(_resolution == Outcome.YES ||
               _resolution == Outcome.NO ||
               _resolution == Outcome.UNDECIDEABLE);

        // Prevent re-entry
        LogResolution(msg.sender, _resolution);
        resolution = _resolution;

        // Claims can be made up to one year from now
        ownerClaimsAllFundsTimestamp = now + SECONDS_PER_YEAR;

        if (resolution == Outcome.UNDECIDEABLE) {
            // Everyone is refunded, and sponsor gets nothing.
            // Owner confiscates sponsor's deposit. // TODO!
            // Sponsor should have been more precise.
            payoutMultiplierInBasisPoints = ONE_HUNDRED_PERCENT_IN_BASIS_POINTS;
            payoutInWei[owner]            = sponsorDepositWei;
            //payoutInWei[sponsor] += 0; // no-op
        } else {
            // Owner and sponsor get some commission. Sponsor gets deposit back.
            // We action these payments later. Doing so now would make a failed send (e.g. out of gas)
            // block resolution.
            // TODO: SafeMath
            payoutInWei[owner]   = (totalCollectedWei * BASIS_POINTS_OWNER_COMMISSION)
                                   / ONE_HUNDRED_PERCENT_IN_BASIS_POINTS;
            payoutInWei[sponsor] += sponsorDepositWei // += becasue owner and sponsor could be the same!
                                   + ((totalCollectedWei * BASIS_POINTS_SPONSOR_COMMISSION)
                                     / ONE_HUNDRED_PERCENT_IN_BASIS_POINTS);

            if (outcomes[uint8(resolution)].predictedWei > 0) {
                // TODO: SafeMath
                payoutMultiplierInBasisPoints = (COMMISSION_ADJUSTED_PAYOUT_MULTIPLIER_IN_BASIS_POINTS
                                                  * totalCollectedWei) / outcomes[uint8(resolution)].predictedWei;
            } 
            else {
                // No one predicted correctly. Owner claims whatever remains.
                payoutInWei[owner] += totalCollectedWei - (payoutInWei[sponsor] + payoutInWei[owner]);
            }
        }   
    }

    function predictYes()
        public
        notWhilePaused
        payable
    {
        predict(Outcome.YES);
    }

    function predictNo()
        public
        notWhilePaused
        payable
    {
        predict(Outcome.NO);
    }

    // Naive, with terrible prediction incentivisation.
    // Should be overridden by meaningful implementations.
    function predict(Outcome _outcome)
        notWhilePaused
        internal
    {
        require(isOpenForPredictions());
        require(_outcome != Outcome.UNRESOLVED);
        require(_outcome != Outcome.UNDECIDEABLE);
        require(msg.value > MIN_STAKE_IN_WEI);
        
        outcomes[uint8(_outcome)].predictions[msg.sender] += msg.value;
        outcomes[uint8(_outcome)].predictedWei += msg.value;
        totalCollectedWei += msg.value;
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
            // Special case. Refund both YES and NO predictions.
            paidIn =   outcomes[uint8(Outcome.YES)].predictions[predictor]
                     + outcomes[uint8(Outcome.NO)].predictions[predictor];
            outcomes[uint8(Outcome.YES)].predictions[predictor] = 0;
            outcomes[uint8(Outcome.NO)].predictions[predictor] = 0;
        } else {
            paidIn = outcomes[uint8(resolution)].predictions[predictor];
            outcomes[uint8(resolution)].predictions[predictor] = 0;
        }

        // Scale the input amount to get an output amount, then pay it.
        // TODO: SafeMath        
        var payout = (paidIn * payoutMultiplierInBasisPoints) / ONE_HUNDRED_PERCENT_IN_BASIS_POINTS;
        assert(payout <= paidIn);
        predictor.transfer(payout);

        // TODO: event
    }


    function claimCommission(address beneficiary)
        public
        notWhilePaused
    {
        require(!isOpenForPredictions());
        require(resolved());
        require(beneficiary == owner || beneficiary == sponsor);
        require(payoutInWei[beneficiary] > 0);
        var sendWei = payoutInWei[beneficiary];
        payoutInWei[beneficiary] = 0;
        beneficiary.transfer(sendWei);
        // TODO: event
    }
    
    
    // TODO: How to we ensure owner/sponsor (could be same person)
    // doesn't abuse pause() to maximise his own winnings?
    // Override (un)pause() to delay the earliest suicide date?
    // his may limit the efficacy of pause in case of critical bugs.
    // One possible solution here is social/economic rather than code -
    // the owner is the hub, so owner may have an incentive
    // to ensure fair treatment of predictors if it wants any future business.

    // Claim any excess ether - e.g. rounding errors, unclaimed payouts, & ether suicided to contract after payout calculations
    function killSelf()
        // Only the sponsor can choose to selfdestruct, because contract might still receive ether inadvertantly from other suicides
        // and once we suicide such income becomes forever unrecoverable
        public
        notWhilePaused
        onlyOwner 
    {
        require(!isOpenForPredictions());
        require(resolved());
        require(now > ownerClaimsAllFundsTimestamp);
        // TODO: event
        selfdestruct(sponsor);
    }
        


    
    
  

}