<template>
    <div>
        <progress v-if="!loaded" class="progress is-small is-light" max="100">15%</progress>
        <div v-if="loaded" class="panel">
            <p class="panel-heading">
                <span class="is-title is-fat is-uppercase">Your Tix</span>
                <span class="tag is-light pull-right" v-if="showTickets === 'current'">{{currentTickets.length}}</span>
                <span class="tag is-light pull-right" v-if="showTickets === 'past'">{{pastTickets.length}}</span>
            </p>
            <p class="panel-tabs">
                <a :class="{'is-active':(showTickets === 'current')}" @click="showTickets = 'current'">Current</a>
                <a :class="{'is-active':(showTickets === 'past')}" @click="showTickets = 'past'" v-if="pastTickets.length > 0">Past</a>
            </p>

            <div class="tickets" v-if="showTickets === 'current'">
                <div class="columns is-multiline">
                    <div class="column is-4" v-for="ticket in currentTickets" :key="ticket">
                        <TicketCard
                                :contract="contract"
                                :ticketId="ticket"
                                :account="account"
                                :ticketFloor="ticketFloor"
                                :prevTicketFloor="prevTicketFloor"
                        />
                    </div>
                    <div class="column" v-if="currentTickets.length === 0">
                        <p class="empty">You don't own any current tickets.</p>
                    </div>
                </div>
            </div>

            <div class="tickets" v-if="showTickets === 'past'">
                <div class="burn-button has-text-centered" v-if="pastTickets.length > 0">
                    <button class="button" @click="burnTickets" :disabled="burnInProgress">
                        <span class="icon">
                            <i class="fas fa-fire" v-if="!burnInProgress"></i>
                            <i class="fab fas fa-spinner fa-pulse" v-if="burnInProgress"></i>
                        </span>
                        <span>Burn Expired Tickets</span>
                    </button>
                </div>
                <div class="columns is-multiline">
                    <div class="column is-4" v-for="ticket in pastTickets" :key="ticket">
                        <TicketCard
                                :contract="contract"
                                :ticketId="ticket"
                                :account="account"
                                :ticketFloor="ticketFloor"
                                :prevTicketFloor="prevTicketFloor"
                        />
                    </div>
                    <div class="column" v-if="pastTickets.length === 0">
                        <p class="empty">You don't own any past tickets.</p>
                    </div>
                </div>
            </div>


        </div>
    </div>
</template>

<script>

    import TicketCard from './TicketCard';

    export default {
        name: 'Tickets',
        data: () => {
            return {
                loaded: false,
                showTickets: 'current',
                currentLotteryId: 0,
                ticketFloor: 0,
                prevTicketFloor: 0,
                lottery: {},
                tickets: [],
                currentTickets: [],
                pastTickets: [],
                burnInProgress: false
            }
        },
        props: {
            refresh: Number,
            contract: Object,
            account: String
        },
        watch: {
            refresh: function () {
                this.loadTickets();
            }
        },
        components: {
            TicketCard
        },
        mounted: function() {
            this.loadTickets();
        },
        methods: {
            loadTickets: async function() {
                this.loaded = false;
                this.ticketFloor = parseInt(await this.contract.ticketFloor.call({from: this.account}));
                this.prevTicketFloor = parseInt(await this.contract.prevTicketFloor.call({from: this.account}));
                this.tickets = await this.contract.getMyTickets({from: this.account});
                this.tickets = this.tickets.reverse();
                this.currentTickets = [];
                this.pastTickets = [];
                let ticketId;
                for(let i in this.tickets) {
                    ticketId = parseInt(this.tickets[i]);
                    if(ticketId > this.ticketFloor) {
                        this.currentTickets.push(ticketId);
                    } else {
                        this.pastTickets.push(ticketId);
                    }
                }
                this.loaded=true;
            },
            burnTickets: async function() {
                this.burnInProgress = true;
                await this.contract.burnExpired({from: this.account});
                this.burnInProgress = false;
                this.loadTickets();
            }
        }
    }
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
    .panel {
        transition: 1s;
    }
    .tickets,
    .tickets .columns {
        width: 100%;
    }
    .tickets {
        padding: 1.5em 0 1.5em 1.5em;
    }
    .tickets .columns {
    }
    p.empty {
        padding: 0 1em;
    }
    .burn-button {
        padding-bottom: 1.5em;
    }
</style>
