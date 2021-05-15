let NETWORKS = {
    rinkeby: {
        id: 4,
        name: 'rinkeby',
        chainlink: {
            coordinator: '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B',
            link: '0x01BE23585060835E02B77ef475b0Cc51aA1e0709',
            keyHash: '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311',
        },
        synthetix: {
            resolver: '0x06868d70c75148327281Cb434624294c946DA1FC'
        }
    },
    kovan: {
        id: 42,
        name: 'kovan',
        chainlink: {
            coordinator: '0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9',
            link: '0xa36085f69e2889c224210f603d836748e7dc0088',
            keyHash: '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4',
        },
        synthetix: {
            resolver: '0x84f87E3636Aa9cC1080c07E6C61aDfDCc23c0db6',
            susd: '0x1150FcF21c5fb154e971fb526A0A777907F87579',
            susdJson: 'https://raw.githubusercontent.com/Synthetixio/synthetix-js/master/lib/abis/rinkeby/ProxyERC20.json'
        }
    },
    development: {
        id: 5777,
        name: 'development',
        chainlink: {
            coordinator: '0x8e6dCd9F25eC9be4Eae83fD4baD59784913F76CB',
            link: '0x8e6dCd9F25eC9be4Eae83fD4baD59784913F76CB',
            keyHash: '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311',
        },
        synthetix: {
            resolver: '0x8e6dCd9F25eC9be4Eae83fD4baD59784913F76CB'
        }
    }
};
NETWORKS[4] = NETWORKS.rinkeby;
NETWORKS[42] = NETWORKS.kovan;
NETWORKS[5777] = NETWORKS.development;

export default NETWORKS;
