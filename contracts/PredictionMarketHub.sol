pragma solidity 0.4.15;

import "./PausableByOwner.sol";
import "./PredictionMarketQuestionBase.sol";


contract PredictionMarketHub is PausableByOwner {
    
    event LogPredictionMarketQuestionCreated(
            address owner,
            address _sponsor,
            string  _questionText,
            address _trustedOracle,
            uint    _closesToPredictionsAtTimestamp);

    uint constant SECONDS_IN_AN_HOUR = 60 * 60;

    function createPredictionMarketQuestion(
        string  _questionText,
        address _trustedOracle,
        uint    _closesToPredictionsAtTimestamp
    ) returns (address) {
        // TODO input validation - non-empty addresses
        require(_closesToPredictionsAtTimestamp > now + SECONDS_IN_AN_HOUR);
        LogPredictionMarketQuestionCreated(this,
                                           msg.sender,
                                           _questionText,
                                           _trustedOracle,
                                           _closesToPredictionsAtTimestamp);
        return new PredictionMarketQuestionBase(msg.sender,
                                                _questionText,
                                                _trustedOracle,
                                                _closesToPredictionsAtTimestamp);
    }
}