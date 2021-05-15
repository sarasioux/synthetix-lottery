<template>
  <div id="app">
    <SiteNav
        v-on:connect="connectWeb3"
        :contract="contract"
        :isConnected="isConnected"
        :account="account"
        :balance="balance"
    />
    <progress v-if="!isConnected && !connectionInProgress" class="progress is-small is-light" max="100">15%</progress>
    <div class="main-container container" v-if="isConnected">
      <h1 class="title is-1 is-fat has-text-centered">{{web3Networks[networkId]}} <span class="has-text-success">sUSD</span> LOTTERY</h1>
      <Prizes
          v-if="ready"
          v-on:claim="eventClaim"
          :refresh="refreshPrizes"
          :contract="contract"
          :account="account"
      />
      <div class="columns">
        <div class="column">
          <CurrentLottery
                  v-if="ready"
                  v-on:purchase="eventPurchase"
                  :refresh="refreshCurrent"
                  :contract="contract"
                  :account="account"
          />
          <Unclaimed
                  v-if="ready"
                  :refresh="refreshPast"
                  :contract="contract"
                  :account="account"
                  class="past-lotteries"
          />
        </div>
        <div class="column">
          <Tickets
                  v-if="ready"
                  v-on:claim="eventClaim"
                  :refresh="refreshTix"
                  :contract="contract"
                  :account="account"
          />
        </div>
      </div>
    </div>
    <Debug
            v-if="ready"
            v-on:reset="eventReset"
            :refresh="refreshDebug"
            :contract="contract"
            :account="account"
    />
  </div>
</template>

<script>
    import './assets/css/lottery.css'
    import LotteryTicketContract from './assets/contracts/LotteryTicket.json'
    import TruffleContract from '@truffle/contract'

    import Prizes from './components/Prizes'
    import Tickets from './components/Tickets'
    import CurrentLottery from './components/CurrentLottery'
    import Unclaimed from './components/Unclaimed'
    import SiteNav from './components/SiteNav'
    import Debug from './components/Debug'


    export default {
        name: 'App',
        data: () => {
            return {
                web3: false,
                isConnected: false,
                connectionInProgress: false,
                isListening: false,
                account: '',
                balance: '',
                contract: {},
                testContract: {},
                ready: false,
                networkId: 0,
                web3Networks: {
                    4: 'RINKEBY',
                    5777: 'GANACHE',
                    42: 'KOVAN'
                },
                refreshTix: 0,
                refreshCurrent: 0,
                refreshPast: 0,
                refreshPrizes: 0,
                refreshDebug: 0
            }
        },
        components: {
            SiteNav, Tickets, CurrentLottery, Unclaimed, Prizes, Debug
        },
        mounted: function() {
            this.isListening = this.$web3Listening;
        },
        methods: {
            connectWeb3: async function() {
                this.connectionInProgress = true;
                try {
                    // Request account access
                    const accounts = await this.$web3.currentProvider.send('eth_requestAccounts');
                    this.isConnected = true;
                    this.account = accounts.result[0];
                    this.getWeb3Values();
                    this.initContracts();
                    this.connectionInProgress = false;

                    //this.eventFind();

                } catch (error) {
                    // User denied account access
                    console.log('did not receive accts', error);
                }
            },
            getWeb3Values: async function() {
                this.networkId = await this.$web3.eth.net.getId();
                this.balance = await this.$web3.eth.getBalance(this.account);
                this.$web3.eth.defaultAccount = this.account;

                this.networkId = await this.$web3.eth.net.getId();
            },
            initContracts: async function() {
                let contract = TruffleContract(LotteryTicketContract);
                contract.setProvider(this.$web3.currentProvider);
                contract.defaults({
                    from: this.account,
                    gasPrice: 1000000000
                });
                this.contract = await contract.deployed();
                this.ready = true;
            },
            eventPurchase: function() {
                this.refreshTix = Date.now();
                this.refreshDebug = Date.now();
            },
            eventReset: function() {
                this.refreshTix = Date.now();
                this.refreshCurrent = Date.now();
                this.refreshPast = Date.now();
                this.refreshPrizes = Date.now();
                this.refreshDebug = Date.now();
            },
            eventClaim: function() {
                this.refreshTix = Date.now();
                this.refreshPrizes = Date.now();
                this.refreshDebug = Date.now();
            },
            eventFind: function() {

            }
        }
    }
</script>

<style>
  html, body, #app {
    height: 100%;
  }
  #app {

  }
  .pull-right {
    float: right;
  }
  .past-lotteries {
    margin-top: 1.5em;
  }
</style>
