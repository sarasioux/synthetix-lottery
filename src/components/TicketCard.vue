<template>
    <div>
        <div class="card" :class="{'has-background-success-light':(prize > 0)}">
            <div class="card-content">
                <a @click="showModal = true" class="send-icon has-text-grey-lighter">
                  <span v-if="isCurrent" class="icon">
                    <i class="fas fa-share"></i>
                  </span>
                </a>
                <div class="media">
                    <div class="media-left">
                        <span class="icon is-large">
                            <span class="fa-stack fa-lg" v-if="prize === 0">
                                <i class="fas fa-ticket-alt fa-stack-2x has-text-dark"></i>
                            </span>
                            <span class="fa-stack fa-lg" v-if="prize > 0">
                                <i class="fas fa-award fa-stack-2x has-text-success"></i>
                            </span>
                        </span>
                    </div>
                    <div class="media-content">
                        <h3 class="ticket-meta is-title is-3">
                            <span class="is-fat">TIX</span><span class="has-text-weight-bold">-{{ticketId}}</span>
                        </h3>
                        <code v-if="prize == 0 && loaded" class="tag is-light">
                            {{ isCurrent ? 'Current' : 'Expired' }}
                        </code>
                        <progress v-if="!loaded" class="progress is-small is-light" max="100">15%</progress>
                        <span class="tag is-success" v-if="prize > 0">{{ prize / ethMultiplier }} sUSD</span>
                    </div>
                </div>
            </div>
        </div>
        <div class="modal" v-if="isCurrent" :class="{'is-active':showModal}">
            <div class="modal-background" @click="showModal = false"></div>
            <div class="modal-card">
                <header class="modal-card-head">
                    <p class="modal-card-title">Transfer Ticket</p>
                    <button class="delete" aria-label="close" @click="showModal = false"></button>
                </header>
                <section class="modal-card-body">
                    <div class="field">
                        <label class="label">Send to Address</label>
                        <div class="control has-icons-left has-icons-right">
                            <input v-model="transferAddress" class="input" type="text" placeholder="0x3144...">
                            <span class="icon is-small is-left">
                              <i class="fab fa-ethereum"></i>
                            </span>
                        </div>
                        <p class="help">Make sure this is a valid address on your current network.</p>
                    </div>
                </section>
                <footer class="modal-card-foot">
                    <button class="button is-success" @click="sendTicket">Send Ticket</button>
                    <button class="button" @click="showModal = false">Cancel</button>
                </footer>
            </div>
        </div>
    </div>
</template>

<script>

    export default {
        name: 'TicketCard',
        data: () => {
            return {
                loaded: false,
                lotteryId: 0,
                prize: 0,
                isCurrent: false,

                showModal: false,
                transferAddress: '',
                ethMultiplier: 1000000000000000000,

            }
        },
        props: {
            contract: Object,
            ticketId: Number,
            account: String,
            ticketFloor: Number,
            prevTicketFloor: Number,
        },
        mounted: function() {
            this.loadTicket();
        },
        methods: {
            loadTicket: async function() {
                this.prize = parseInt(await this.contract.ticketToPrize.call(this.ticketId, {from: this.account}));
                if(this.ticketId > this.ticketFloor) {
                    this.isCurrent = true;
                }
                this.loaded = true;
            },
            sendTicket: async function() {
                // 0xA8a912f12FE9E6638bC0DBad8637672Cc19bcEb9
                if(this.account) {
                    await this.contract.safeTransferFrom(this.account, this.transferAddress, this.ticketId, {from: this.account});
                    this.$emit('transfer');
                    this.transferAddress = '';
                    this.showModal = false;
                }
            }
        }
    }
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
    .card {
    }
    .card-content {
        padding: 0.6em 1em;
    }
    .card:hover {
        background: #f6f6f6;
    }
    .send-icon {
        position: absolute;
        top: 0.3em;
        right: 0.3em;
    }
    .send-icon:hover .icon {
        color: #48c774;
    }
    code.tag {
        margin: 0 0.2em;
    }
    .ticket-meta {
        font-size: 0.8em;
    }
    .tag {
        padding: 0 1em;
    }
</style>
