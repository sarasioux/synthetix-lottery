<template>
    <div>
        <progress v-if="!loaded" class="progress is-small is-light" max="100">15%</progress>
        <div class="panel" v-if="loaded">
            <p class="panel-heading">
                <span class="is-fat is-uppercase">Current Lottery</span>
                <span class="tag is-light pull-right">Ends {{formatDateTag()}}</span>
            </p>
            <div class="columns">
                <div class="column">
                    <div class="box is-dark has-text-centered">
                        <div class="subtitle is-5">Prize</div>
                        <p class="title is-4 has-text-success has-text-weight-bold">{{ prize }} <span>sUSD</span></p>
                    </div>
                </div>
                <div class="column">
                    <div class="box has-text-centered">
                        <div class="subtitle is-5">Ends</div>
                        <p class="title is-4 has-text-success has-text-weight-bold">{{ formattedDate }}</p>
                    </div>
                </div>
            </div>
            <div class="message is-warning" v-if="end < Date.now()">
                <div class="message-body">
                    Buy a ticket to award prizes and start a new lottery.
                </div>
            </div>
            <div class="columns form">
                <div class="column">
                    <div class="field has-addons" :disabled="purchaseInProgress">
                        <div class="control">
                            <input v-model="ticketQty" class="input ticket-qty" type="number" placeholder="1" />
                        </div>
                        <p class="control">
                            <a class="button is-static">
                                TIX
                            </a>
                        </p>
                    </div>
                </div>
                <div class="column is-5 has-text-centered">
                    <h3 class="title is-3 has-text-dark has-text-weight-bold">{{ticketQty * ticketPrice}} sUSD</h3>
                </div>
                <div class="column has-text-right">
                    <button v-if="allowance >= ticketQty * ticketPrice" class="button is-success" @click="buyTicket" :disabled="purchaseInProgress">
                        <span class="icon">
                            <i class="fab fa-ethereum" v-if="!purchaseInProgress"></i>
                            <i class="fab fas fa-spinner fa-pulse" v-if="purchaseInProgress"></i>
                        </span>
                        <span>Buy Now</span>
                    </button>
                    <button v-if="allowance < ticketQty * ticketPrice" class="button is-green-dark" @click="getApproval" :disabled="approvalInProgress">
                        <span class="icon">
                            <i class="fab fa-ethereum" v-if="!approvalInProgress"></i>
                            <i class="fab fas fa-spinner fa-pulse" v-if="approvalInProgress"></i>
                        </span>
                        <span>Approve</span>
                    </button>
                </div>
            </div>
            <div class="approval-message is-small has-text-grey has-text-centered">
                You have approved this contract for {{allowance}} sUSD.
            </div>
        </div>
    </div>
</template>

<script>

    const { SynthetixJs } = require('synthetix-js');
    import moment from 'moment';

    export default {
        name: 'CurrentLottery',
        data: () => {
            return {
                loaded: false,
                purchaseInProgress: false,
                approvalInProgress: false,
                id: 0,
                end: 0,
                prize: 0,
                ticketFloor: 0,
                totalTickets: 0,
                tickets: [],
                formattedDate: '',
                ticketQty: 1,
                ticketPrice: 5,
                allowance: 0
            }
        },
        props: {
            refresh: Number,
            contract: Object,
            account: String
        },
        watch: {
            refresh: function () {
                this.loadLottery();
            },
        },
        mounted: function() {
            this.loadLottery();
        },
        methods: {
            getApproval: async function() {
                this.approvalInProgress = true;
                const totalSpend = this.ticketQty * this.ticketPrice;
                const networkId = await this.$web3.eth.net.getId();

                const metaMaskSigner = new SynthetixJs.signers.Metamask();
                const snxjs = new SynthetixJs({ signer: metaMaskSigner, networkId: networkId }); //uses Metamask signer and default infura.io provider on mainnet
                let self = this;
                snxjs.sUSD.approve(this.contract.address, totalSpend)
                    .then(function(err, response) {
                        console.log('approval request returned', err, response);
                        self.checkAllowance();
                    });
            },
            buyTicket: async function() {
                this.purchaseInProgress = true;
                // Save some gas on a single ticket purchase
                await this.contract.buyTickets( this.ticketQty, {from: this.account});

                this.purchaseInProgress = false;
                this.$emit('purchase');
                this.loadLottery();
            },
            loadLottery: async function() {
                this.end = parseInt(await this.contract.end.call({from: this.account})) * 1000;
                this.formatDate();

                this.ticketFloor = parseInt(await this.contract.ticketFloor.call({from: this.account}));
                this.totalTickets = parseInt(await this.contract.ticketId.call({from: this.account}));
                this.prize = (this.totalTickets - this.ticketFloor) * this.ticketPrice;
                this.checkAllowance();
                this.loaded=true;
            },
            formatDate: function() {
                let d = new Date(this.end);
                this.formattedDate = moment(d).fromNow();
                setTimeout(() => this.formatDate(), 5000);
            },
            formatDateTag: function() {
                let d = new Date(this.end);
                return moment(d).format('MMMM Do YYYY') + ' at ' + moment(d).format('h:mm a');
            },
            checkAllowance: async function() {
                let allowance = parseInt(await this.contract.checkTokenAllowance(this.account, this.contract.address, {from: this.account}));
                this.allowance = allowance;
                return allowance;
            }
        }
    }
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
    .box {
        min-height: 115px;
    }
    .columns {
        padding: 1.5em;
        padding-bottom: 0;
    }
    button {
        margin: 0 0 1.5em 1em;
    }
    .message {
        margin: 1em 1.5em;
    }
    .ticket-qty {
        width: 5em;
    }
    .form .column {
        padding-top: 0;
        padding-bottom: 0;
    }
    .refresh-button {
        margin-left: 0.5em;
    }
    .is-small {
        font-size: 0.9em;
    }
    .approval-message {
        padding-bottom: 1.5em;
    }
</style>
