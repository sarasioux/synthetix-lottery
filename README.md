# Synthetix Lottery

![Screenshot](https://raw.githubusercontent.com/sarasioux/synthetix-lottery/master/src/assets/screenshot.png)

## Overview

Entry for Gitcoin Bounty:
https://gitcoin.co/issue/snxgrants/open-defi-hackathon/8/100025689

This is the first dApp + Smart Contract I have ever coded so please be nice and I welcome any and all feedback to help me get better.  This was a lot of fun to work on because it touched a lot of different smart contract concepts which were challenging to learn.

My goal with this development was to make a lottery system that is as permanent, reliable, and self-sustainable as possible.  That means that no administrative activities should be required to keep the lottery operating indefinitely.

Check out the lottery in action on the Kovan network here:
https://synthetixlottery.netlify.app/

## Features

The contract features several advanced capabilities, such as:
* Lottery starts automatically when contract is deployed.
* Lottery ends and prizes are awarded automatically when a ticket is purchased past expiration.
* Users can force the lottery to award prizes without purchasing a ticket.
* Users can burn expired non-winning tickets so they don't hold them forever.
* Users can purchase more than one ticket at a time.
* Lottery system retains a 1% fee (to pay for LINK).
* Contract owner can withdraw lottery fees from the contract.

All contract features are implemented in the dApp, as well as:
* Users can approve more tickets than they intend to purchase, so they don't have to approve every time.
* Users can claim all of their tickets at one time.
* Users can transfer tickets to another address.
* Users can see their past and current tickets.
* Users can see all recently awarded prizes.
* Lottery expiration counts down automatically.
* There's a little bug icon you can click on to see lottery internals.
* There's a bunch of confetti when you win a prize.


## Prizes
Prizes are awarded as follows:
* 1 ticket entry wins 100% of prize pool (money back, minus fee).
* 2 ticket entries win 50% of prize pool (money back, minus fee).
* 3 or more ticket entries win splits of 50%, 35%, and 15%.


## Data

Significant effort went into attempting to optimize gas usage, to avoid having gas fees be more expensive than the lottery ticket itself.

For this reason, the contract does not keep track of past lotteries or winners after they have claimed their prizes, but that information could be displayed by tracking the contract's events.  Instead of tracking individual lotteries with an ID which increased contract size and gas fees, this contract tracks lotteries by their ticket id "floor".

Valid tickets for the *current* lottery could be expressed as:

* ``Ticket Floor < Valid Ticket IDs <= Current Ticket Id``

Valid tickets for the *previous* lottery could be expressed as:

* ``Previous Ticket Floor < Valid Ticket IDs <= Ticket Floor``

The contract only remembers the ticket floor for the current and previous lotteries to support awarding of prizes.

## TODO
If I were to continue working on this app, there are several things I would still want to implement, such as:
* Listen to Metamask connection changes for a smoother Web3 experience
* Add automatic conversion from sUSD to LINK.
* Write automated tests.
* Make tickets look cooler, with a modal to display their NFTness.
* Optimize reloading of data on changes (pretty brute force right now).
* Optimize for mobile & tablet displays.
* Catch errors in web3 (i.e. user rejects transaction and they have to reload the page)
* Show stats about your current odds of winning.
* Add an about page.
* Add explanatory text on the pre-connection landing page.
* Customize the app/token icon in Metamask.

## Configurations

### Lottery
Update the constant values at the top of LotteryTicket.sol to customize lottery behaviors.  Available configurations are:
* ``ticketPrice`` Currently set to $5 sUSD.
* ``duration`` Currently set to 10 minutes for testing purposes.
* ``lotteryFee`` Currently set to 1%.

Be sure to update the corresponding ``ticketPrice`` in the front end if you change it in the contract.

### Truffle
* Put your contract owner's mnemonic into a ``.secret`` file in the project root.
* Update infura links in truffle-config.js.


This contract requires LINK in order to interface with Chainlink's verifiable randomness oracle.  Be sure to transfer some LINK in when you redeploy.

## Project setup
```
npm install
```

### Compiles and hot-reloads for development
```
npm run serve
```

### Compiles and minifies for production
```
npm run build
```

### Lints and fixes files
```
npm run lint
```

### Compile Bulma theme
```
npm run css-build
```

### Compile contracts
```
truffle compile
```

### Migrate contracts
```
truffle migrate --network kovan
```
