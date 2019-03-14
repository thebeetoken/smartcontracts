
module.exports = {
    // formats result from PullReputationScore into a dict
    cleansePullReputationScore: async promise => {
        let thrown = undefined;
        try {
            let result = await promise;
            return {reviewTotal: result[0],
            reviewCount: result[1],
            personalTotal: result[2],
            personalCount: result[3],
            bookingTotal: result[4],
            bookingCount: result[5],
            miscTotal: result[6],
            miscCount: result[7],
            userScore: result[8]}
        } catch (error) {
          throw error;
        }
    },
}
