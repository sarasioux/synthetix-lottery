const Lottery = artifacts.require("LotteryTicket");
const config = require('../truffle-config.js');

module.exports = function(deployer, network) {

    const networkName = network.replace('-fork', '');
    const cfg = config.networks[networkName];
    
    console.log('network name', networkName);
    deployer.deploy(Lottery,
        cfg.chainlink.coordinator,
        cfg.chainlink.link,
        cfg.synthetix.resolver,
        cfg.chainlink.keyHash,
    );

};
