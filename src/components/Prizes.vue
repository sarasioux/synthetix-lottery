<template>
    <div class="columns">
        <div class="column is-half is-offset-one-quarter">
            <div class="box winners-box has-background-success-light" v-if="unclaimedPrizes > 0">
                <div class="columns">
                    <div class="column is-2">
                        <div class="award-icon icon is-large">
                            <span class="fa-stack fa-lg">
                              <i class="fas fa-award fa-3x has-text-success"></i>
                            </span>
                        </div>
                    </div>
                    <div class="column">
                        <div class="subtitle is-6 has-text-dark">Unclaimed Prizes</div>
                        <div class="title is-2 has-text-dark has-text-weight-bold is-fat">{{unclaimedPrizes}} sUSD</div>
                    </div>
                    <div class="column has-text-right">
                        <button class="button is-success is-large" @click="claimPrizes">
                            <span class="icon">
                            <i class="fab fa-ethereum"></i>
                            </span>
                            <span>Claim Prizes</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import confetti from 'canvas-confetti';
export default {
    name: 'Prizes',
    data: () => {
        return {
            tickets: [],
            unclaimedPrizes: 0
        }
    },
    props: {
        contract: Object,
        account: String,
        refresh: Number
    },
    watch: {
        refresh: function () {
            this.checkPrizes();
        }
    },
    mounted: function() {
        this.checkPrizes();
    },
    methods: {
        checkPrizes: async function() {
            this.tickets = await this.contract.getMyTickets({from: this.account});
            if(this.tickets.length > 0) {
                let unclaimedPrizes = 0;
                let ticketId;
                for(let i in this.tickets) {
                    ticketId = parseInt(this.tickets[i]);
                    unclaimedPrizes += parseInt(await this.contract.ticketToPrize.call(ticketId, {from: this.account}));
                }
                if(unclaimedPrizes > this.unclaimedPrizes && unclaimedPrizes > 0) {
                    this.confetti();
                }
                this.unclaimedPrizes = unclaimedPrizes;
            }
        },
        claimPrizes: async function() {
            await this.contract.claimMyPrizes({from: this.account});
            this.$emit('claim');
            this.checkPrizes();
        },
        confetti: function() {
            let colors = ['#48c774', '#328b51', '#91ddac'];
            let end = Date.now() + (4 * 1000);
            (function frame() {
                confetti({
                    particleCount: 3,
                    angle: -90,
                    spread: 200,
                    origin: { y: -0.2 },
                    colors: colors
                });
                if (Date.now() < end) {
                    requestAnimationFrame(frame);
                }
            }());
        }
    }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
    .award-icon {
        margin: 0.4em;
    }
    button {
        margin-top: 0.5em;
        margin-right: 0.5em;
    }

</style>
