pragma solidity 0.4.15;

import "./PredictionMarketQuestionBase.sol";

// TEST ONLY
// Mockable contract to simplify testing of PredictionMarketQuestionBase
contract PredictionMarketQuestionMockable is PredictionMarketQuestionBase() {
    uint public currentTime; // TODO: generates a warning. Perhaps 

    function setCurrentTime(uint mockedNow) {
        currentTime = mockedNow;
    }

    function currentTime() returns (uint) {
        return currentTime;
    }

    // COnstructor
    function PredictionMarketQuestionMockable(
                        address _sponsor,
                        string _questionText,
                        address _trustedOracle,
                        uint    _closesToPredictionsAtTimestamp)
             PredictionMarketQuestionBase(
                        _sponsor,
                        _questionText,
                        _trustedOracle,
                        _closesToPredictionsAtTimestamp)
    payable
    {
    }
}