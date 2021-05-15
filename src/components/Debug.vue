<template>
    <div>
        <div class="modal" :class="{'is-active':showDebug}">
            <div class="modal-background" @click="showDebug=false"></div>
            <div class="modal-content">
                <nav class="panel" v-if="loaded && showDebug">
                    <p class="panel-heading is-fat is-uppercase">
                        Lottery Internals
                    </p>
                    <p class="panel-block">
                        <span class="label">Contract Address</span> <span class="tag">{{contract.address}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">If Lottery Ended</span> <a @click="refreshLottery">Refresh Lottery</a>
                    </p>
                    <p class="panel-block">
                        <span class="label">Current Ticket Id</span> <span class="tag">{{ticketId}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">Current Ticket Floor</span> <span class="tag">{{ticketFloor}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">Previous Ticket Floor</span> <span class="tag">{{prevTicketFloor}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">Contract Allowance</span> <span class="tag">{{allowance}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">Contract Money</span> <span class="tag">{{contractMoney}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">Ticket0 Balance</span> <span class="tag">{{ticket0}}</span>
                    </p>
                    <p class="panel-block">
                        <span class="label">Request ID</span> <span class="tag">{{requestId}}</span>
                    </p>
                </nav>
            </div>
            <button  @click="showDebug=false" class="modal-close is-large" aria-label="close"></button>
        </div>
        <a @click="showDebug=true" class="is-small is-debug-link">
            <span class="icon">
              <i class="fas fa-bug"></i>
            </span>
        </a>

    </div>
</template>

<script>

    export default {
        name: 'Debug',
        data: () => {
            return {
                loaded: true,
                showDebug: false,
                ticketId: 0,
                ticketFloor: 0,
                prevTicketFloor: 0,
                allowance: 0,
                ticket0: 0,
                contractMoney: 0,
                requestId: 0,
            }
        },
        props: {
            contract: Object,
            account: String,
        },
        watch: {
            showDebug: function () {
                this.loadDebug();
            },
        },
        mounted: function() {
            this.loadDebug();
        },
        methods: {
            loadDebug: async function() {
                this.ticketId = parseInt(await this.contract.ticketId.call({from: this.account}));
                this.ticketFloor = parseInt(await this.contract.ticketFloor.call({from: this.account}));
                this.prevTicketFloor = parseInt(await this.contract.prevTicketFloor.call({from: this.account}));
                this.allowance = parseInt(await this.contract.checkTokenAllowance(this.account, this.contract.address, {from: this.account}));
                this.contractMoney = parseInt(await this.contract.contractMoney.call({from: this.account}));
                this.ticket0 = parseInt(await this.contract.ticketToPrize.call(0, {from: this.account}));
                this.requestId = await this.contract.requestId.call({from: this.account});

            },
            refreshLottery: async function() {
                await this.contract.endLottery({from: this.account});
                this.$emit('reset');
            },
        }
    }
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
    .tickets {
        padding: 1.5em;
    }
    .label {
        font-weight: normal;
        display: block;
        padding-right: 20px;
        font-size: 0.8em;
        min-width: 160px;
    }
    .is-small {
        font-size: 0.9em;
        color: #48c774;
    }
    .panel {
        background: white;
    }
    .modal-content {
        width: 800px;
    }
    .is-debug-link {
        position: fixed;
        bottom: 10px;
        right: 10px;
    }
</style>
