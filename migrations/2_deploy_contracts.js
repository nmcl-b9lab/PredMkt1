var QuestionLib = artifacts.require("./QuestionLib.sol");
var Owned = artifacts.require("./Owned.sol");
var PausableByOwner = artifacts.require("./PausableByOwner.sol");
var PredictionMarketQuestionBase = artifacts.require("./PredictionMarketQuestionBase.sol");

module.exports = function(deployer) {
  deployer.deploy(Owned);
  deployer.deploy(PausableByOwner);
  
  deployer.deploy(QuestionLib);
  //deployer.link(QuestionLib, PredictionMarketQuestionBase);
  deployer.deploy(PredictionMarketQuestionBase); 
};
